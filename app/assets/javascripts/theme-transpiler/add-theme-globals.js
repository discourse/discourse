export default function (babel) {
  const { types: t } = babel;

  const visitor = {
    CallExpression(path) {
      if (path.node.callee.name === "precompileTemplate") {
        let scope = path.node.arguments[1].properties.find(
          (prop) => prop.key.name === "scope"
        );
        if (!scope) {
          scope = t.objectProperty(
            t.identifier("scope"),
            t.arrowFunctionExpression([], t.objectExpression([]))
          );
          path.node.arguments[1].properties.push(scope);
        }

        scope.value.body.properties.push(
          t.objectProperty(
            t.identifier("themePrefix"),
            t.identifier("themePrefix"),
            false,
            true
          )
        );
        scope.value.body.properties.push(
          t.objectProperty(
            t.identifier("settings"),
            t.identifier("settings"),
            false,
            true
          )
        );
      }
    },

    Program(path) {
      const importDeclarations = [];

      if (path.scope.bindings.themePrefix) {
        if (path.scope.bindings.themePrefix.kind !== "module") {
          throw new Error("duplicate themePrefix");
        } else {
          // TODO: maybe check the import path
        }
      } else {
        importDeclarations.push(
          t.importSpecifier(
            t.identifier("themePrefix"),
            t.identifier("themePrefix")
          )
        );
      }

      if (path.scope.bindings.settings) {
        if (path.scope.bindings.settings.kind !== "module") {
          throw new Error("duplicate settings");
        } else {
          // TODO: maybe check the import path
        }
      } else {
        importDeclarations.push(
          t.importSpecifier(t.identifier("settings"), t.identifier("settings"))
        );
      }

      if (importDeclarations.length > 0) {
        path.node.body.push(
          t.importDeclaration(
            importDeclarations,
            t.stringLiteral("discourse-theme")
          )
        );

        path.scope.crawl();
      }
    },
  };

  return {
    pre(file) {
      babel.traverse(file.ast, visitor, file.scope);
    },
  };
}
