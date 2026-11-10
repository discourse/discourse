import { readDiscourseImportMode } from "./discourse-import-attribute.js";
import rollupVirtualImports from "./rollup-virtual-imports.js";

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

        const lookup = (exportNames = []) => {
          const args = [
            t.stringLiteral(moduleName),
            t.booleanLiteral(optional),
          ];
          if (exportNames.length) {
            args.push(
              t.arrayExpression(exportNames.map((n) => t.stringLiteral(n)))
            );
          }

          return t.callExpression(
            t.memberExpression(
              t.memberExpression(
                t.identifier("window"),
                t.identifier("moduleBroker")
              ),
              t.identifier("lookup")
            ),
            args
          );
        };

        const replacements = [];
        const properties = [];
        const exportNames = [];

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
            exportNames.push(exportedName);
            properties.push(
              t.objectProperty(
                t.identifier(exportedName),
                t.identifier(specifier.local.name)
              )
            );
          }
        }

        if (properties.length) {
          replacements.unshift(
            declare(t.objectPattern(properties), lookup(exportNames))
          );
        }

        path.replaceWithMultiple(replacements);
      },
    },
  };
}
