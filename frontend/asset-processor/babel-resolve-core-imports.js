import { readDiscourseImportMode } from "./discourse-import-attribute.js";
import rollupVirtualImports from "./rollup-virtual-imports.js";

// Core modals load on demand, so their imports go through the async broker.
const LAZY_PREFIX = "discourse/components/modal/";

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
      CallExpression(path) {
        if (
          path.node.callee.type === "Import" &&
          t.isStringLiteral(path.node.arguments[0]) &&
          path.node.arguments[0].value.startsWith(LAZY_PREFIX)
        ) {
          path.replaceWith(
            t.callExpression(
              t.memberExpression(
                t.memberExpression(
                  t.identifier("window"),
                  t.identifier("moduleBroker")
                ),
                t.identifier("load")
              ),
              [path.node.arguments[0]]
            )
          );
        }
      },
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
        const lazy = moduleName.startsWith(LAZY_PREFIX);

        const lookup = () => {
          const expression = t.callExpression(
            t.memberExpression(
              t.memberExpression(
                t.identifier("window"),
                t.identifier("moduleBroker")
              ),
              t.identifier(lazy ? "load" : "lookup")
            ),
            optional
              ? [t.stringLiteral(moduleName), t.booleanLiteral(true)]
              : [t.stringLiteral(moduleName)]
          );
          return lazy ? t.awaitExpression(expression) : expression;
        };

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

        if (lazy && replacements.length === 0) {
          replacements.push(t.expressionStatement(lookup()));
        }

        path.replaceWithMultiple(replacements);
      },
    },
  };
}
