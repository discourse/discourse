import rollupVirtualImports from "./rollup-virtual-imports";

export default function (babel) {
  const { types: t } = babel;

  return {
    visitor: {
      ImportDeclaration(path) {
        const moduleName = path.node.source.value;
        if (moduleName.startsWith(".") || rollupVirtualImports[moduleName]) {
          return;
        }

        const properties = path.node.specifiers.map((specifier) => {
          if (specifier.type === "ImportDefaultSpecifier") {
            return t.objectProperty(
              t.identifier("default"),
              t.identifier(specifier.local.name)
            );
          } else {
            return t.objectProperty(
              t.identifier(specifier.imported.name),
              t.identifier(specifier.local.name)
            );
          }
        });

        const replacement = t.variableDeclaration("const", [
          t.variableDeclarator(
            t.objectPattern(properties),
            t.awaitExpression(
              t.callExpression(
                t.memberExpression(
                  t.memberExpression(
                    t.identifier("window"),
                    t.identifier("moduleBroker")
                  ),
                  t.identifier("lookup")
                ),
                [t.stringLiteral(moduleName)]
              )
            )
          ),
        ]);

        path.replaceWith(replacement);
      },
    },
  };
}
