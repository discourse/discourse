export default function (babel) {
  const { types: t } = babel;

  function rewriteReferences(binding, buildValue) {
    for (const reference of [...binding.referencePaths]) {
      const parent = reference.parentPath;

      if (parent.isExportSpecifier()) {
        throw reference.buildCodeFrameError(
          "Re-exporting a cross-plugin import is not supported. Import and reference it directly instead."
        );
      } else if (
        parent.isObjectProperty({ shorthand: true, value: reference.node })
      ) {
        parent.node.shorthand = false;
        reference.replaceWith(buildValue());
      } else if (parent.isCallExpression({ callee: reference.node })) {
        // `(0, ...)` keeps `this === undefined` for the call.
        reference.replaceWith(
          t.sequenceExpression([t.numericLiteral(0), buildValue()])
        );
      } else {
        reference.replaceWith(buildValue());
      }
    }
  }

  // Marker that discourse-external-loader appends to the external id of an
  // import flagged `with { optional: "true" }`. Optionality rides in the
  // module specifier so it survives bundling in `chunk.imports`.
  const OPTIONAL_MARKER = "?optional";

  return {
    // The original `with { optional: "true" }` attribute is still present on
    // the (now `?optional`-marked) external import, so the parser needs to
    // accept it.
    manipulateOptions(_opts, parserOpts) {
      parserOpts.plugins.push("importAttributes");
    },
    pre() {
      this.pluginImports = new Map();
    },
    visitor: {
      Program: {
        exit(path) {
          const declarations = [];
          for (const [importSource, localId] of this.pluginImports) {
            declarations.push(
              t.importDeclaration(
                [t.importDefaultSpecifier(t.identifier(localId))],
                t.stringLiteral(importSource)
              )
            );
          }
          path.node.body.unshift(...declarations);
        },
      },

      ImportDeclaration(path) {
        let moduleName = path.node.source.value;
        if (!moduleName.startsWith("discourse/plugins/")) {
          return;
        }

        // An optional import arrives as `discourse/plugins/foo/bar?optional`.
        // The consolidated import keeps the marker (`discourse/plugins/foo?`)
        // so the import map can resolve it to a null stub when the plugin is
        // absent, instead of the throwing stub used for required imports.
        const optional = moduleName.endsWith(OPTIONAL_MARKER);
        if (optional) {
          moduleName = moduleName.slice(0, -OPTIONAL_MARKER.length);
        }

        const parts = moduleName.split("/");
        const pluginName = parts[2];
        const compatModuleName = parts.slice(3).join("/");

        const importSource = `discourse/plugins/${pluginName}${optional ? "?" : ""}`;

        let localId = this.pluginImports.get(importSource);
        if (!localId) {
          localId = path.scope.generateUid(
            `plugin_${pluginName}${optional ? "_optional" : ""}`
          );
          this.pluginImports.set(importSource, localId);
        }

        const compatModule = () => {
          const primary = t.memberExpression(
            t.identifier(localId),
            t.stringLiteral(compatModuleName),
            true
          );

          if (
            !compatModuleName ||
            compatModuleName === "index" ||
            compatModuleName.endsWith("/index")
          ) {
            return primary;
          }

          const indexFallback = t.memberExpression(
            t.identifier(localId),
            t.stringLiteral(`${compatModuleName}/index`),
            true
          );

          return t.logicalExpression("||", primary, indexFallback);
        };

        for (const specifier of path.node.specifiers) {
          const localName = specifier.local.name;

          let exportedName;
          if (specifier.type === "ImportDefaultSpecifier") {
            exportedName = "default";
          } else if (specifier.type === "ImportNamespaceSpecifier") {
            exportedName = null;
          } else {
            exportedName = specifier.imported.name;
          }

          const buildValue = () =>
            exportedName
              ? t.memberExpression(compatModule(), t.identifier(exportedName))
              : compatModule();

          rewriteReferences(path.scope.getBinding(localName), buildValue);
        }

        path.remove();
      },
    },
  };
}
