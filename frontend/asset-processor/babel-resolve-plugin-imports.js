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

  return {
    pre() {
      this.pluginImports = new Map();
    },
    visitor: {
      Program: {
        exit(path) {
          const declarations = [];
          for (const [pluginName, localId] of this.pluginImports) {
            declarations.push(
              t.importDeclaration(
                [t.importDefaultSpecifier(t.identifier(localId))],
                t.stringLiteral(`discourse/plugins/${pluginName}`)
              )
            );
          }
          path.node.body.unshift(...declarations);
        },
      },

      ImportDeclaration(path) {
        const moduleName = path.node.source.value;
        if (!moduleName.startsWith("discourse/plugins/")) {
          return;
        }

        const parts = moduleName.split("/");
        const pluginName = parts[2];
        const compatModuleName = parts.slice(3).join("/");

        let localId = this.pluginImports.get(pluginName);
        if (!localId) {
          localId = path.scope.generateUid(`plugin_${pluginName}`);
          this.pluginImports.set(pluginName, localId);
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
