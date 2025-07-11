export default function (babel) {
  const { types: t } = babel;

  let i = 0;

  return {
    visitor: {
      ImportDeclaration(path) {
        const moduleName = path.node.source.value;
        if (!moduleName.match(/^discourse\/theme-\d+\//)) {
          return;
        }

        const [, themeId, innerModulePath] = moduleName.match(
          /^discourse\/theme-(\d+)\/(.*)/
        );

        const moduleVarName = `DiscourseAutoImportMod${i}`;
        i++;

        const scope = path.scope;
        for (const specifier of path.node.specifiers) {
          const binding = scope.bindings[specifier.local.name];
          for (const ref of binding.referencePaths) {
            const replacement = t.memberExpression(
              t.memberExpression(
                t.identifier(moduleVarName),
                t.stringLiteral(innerModulePath),
                true
              ),
              specifier.imported || t.identifier("default")
            );

            ref.replaceWith(replacement);
          }
        }

        const replacementImport = t.importDeclaration(
          [t.importDefaultSpecifier(t.identifier(moduleVarName))],
          t.stringLiteral(`discourse/theme-${themeId}`)
        );

        path.replaceWith(replacementImport);
      },
    },
  };
}
