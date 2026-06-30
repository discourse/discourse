import { readDiscourseImportMode } from "./discourse-import-attribute";
import rollupVirtualImports from "./rollup-virtual-imports";

export default function (babel) {
  const { types: t } = babel;

  const declare = (id, init) =>
    t.variableDeclaration("const", [t.variableDeclarator(id, init)]);

  return {
    manipulateOptions(_opts, parserOpts) {
      // Allow the `with { discourseImport: ... }` attribute to parse.
      if (!parserOpts.plugins.includes("importAttributes")) {
        parserOpts.plugins.push("importAttributes");
      }
    },
    visitor: {
      ImportDeclaration(path) {
        const moduleName = path.node.source.value;
        if (
          moduleName.startsWith(".") ||
          rollupVirtualImports[moduleName] ||
          moduleName.startsWith("discourse/theme-") ||
          moduleName.startsWith("discourse/plugins/")
        ) {
          return;
        }

        // Core imports are required unless explicitly marked optional.
        const optional = readDiscourseImportMode(path) === "optional";

        const lookup = () =>
          t.callExpression(
            t.memberExpression(
              t.memberExpression(
                t.identifier("window"),
                t.identifier("moduleBroker")
              ),
              t.identifier("lookup")
            ),
            optional
              ? [t.stringLiteral(moduleName), t.booleanLiteral(true)]
              : [t.stringLiteral(moduleName)]
          );

        const replacements = [];
        const properties = [];

        for (const specifier of path.node.specifiers) {
          if (specifier.type === "ImportNamespaceSpecifier") {
            replacements.push(
              declare(t.identifier(specifier.local.name), lookup())
            );
          } else {
            const exportedName =
              specifier.type === "ImportDefaultSpecifier"
                ? "default"
                : specifier.imported.name;
            properties.push(
              t.objectProperty(
                t.identifier(exportedName),
                t.identifier(specifier.local.name)
              )
            );
          }
        }

        if (properties.length) {
          replacements.unshift(declare(t.objectPattern(properties), lookup()));
        }

        path.replaceWithMultiple(replacements);
      },
    },
  };
}
