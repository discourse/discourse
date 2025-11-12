import rollupVirtualImports from "./rollup-virtual-imports";

export default function (babel) {
  const { types: t } = babel;

  return {
    visitor: {
      ImportDeclaration(path) {
        const moduleName = path.node.source.value;
        if (
          moduleName.startsWith(".") ||
          rollupVirtualImports[moduleName] ||
          moduleName.startsWith("discourse/theme-")
        ) {
          return;
        }

        const namespaceImports = [];
        const properties = path.node.specifiers
          .map((specifier) => {
            if (specifier.type === "ImportDefaultSpecifier") {
              return t.objectProperty(
                t.identifier("default"),
                t.identifier(specifier.local.name)
              );
            } else if (specifier.type === "ImportNamespaceSpecifier") {
              namespaceImports.push(t.identifier(specifier.local.name));
            } else {
              return t.objectProperty(
                t.identifier(specifier.imported.name),
                t.identifier(specifier.local.name)
              );
            }
          })
          .filter(Boolean);

        const replacements = [];

        const moduleBrokerLookup = t.awaitExpression(
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
        );

        if (properties.length) {
          replacements.push(
            t.variableDeclaration("const", [
              t.variableDeclarator(
                t.objectPattern(properties),
                moduleBrokerLookup
              ),
            ])
          );
        }

        if (namespaceImports.length) {
          for (const namespaceImport of namespaceImports) {
            replacements.push(
              t.variableDeclaration("const", [
                t.variableDeclarator(namespaceImport, moduleBrokerLookup),
              ])
            );
          }
        }

        path.replaceWithMultiple(replacements);
      },
    },
  };
}
