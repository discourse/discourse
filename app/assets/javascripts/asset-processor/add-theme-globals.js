export default function (babel) {
  const { types: t } = babel;

  const visitor = {
    Program(path) {
      const importDeclarations = [];

      if (path.scope.bindings.themePrefix) {
        const themePrefix = path.scope.bindings.themePrefix;

        if (themePrefix.kind !== "module") {
          throw new Error(
            "`themePrefix` is already defined. Unable to add import."
          );
        } else if (themePrefix.path.parent.source.value !== "virtual:theme") {
          throw new Error(
            "`themePrefix` is already imported. Unable to add import from `virtual:theme`."
          );
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
        const settings = path.scope.bindings.settings;
        if (settings.kind !== "module") {
          throw new Error(
            "`settings` is already defined. Unable to add import."
          );
        } else if (settings.path.parent.source.value !== "virtual:theme") {
          throw new Error(
            "`settings` is already imported. Unable to add import from `virtual:theme`."
          );
        }
      } else {
        importDeclarations.push(
          t.importSpecifier(t.identifier("settings"), t.identifier("settings"))
        );
      }

      if (importDeclarations.length > 0) {
        path.node.body.unshift(
          t.importDeclaration(
            importDeclarations,
            t.stringLiteral("virtual:theme")
          )
        );
      }
    },
  };

  return {
    pre(file) {
      babel.traverse(file.ast, visitor, file.scope);
      file.scope.crawl();
    },
  };
}
