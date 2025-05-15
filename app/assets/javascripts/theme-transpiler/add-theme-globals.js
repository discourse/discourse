export default function (babel) {
  const { types: t } = babel;

  const visitor = {
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
