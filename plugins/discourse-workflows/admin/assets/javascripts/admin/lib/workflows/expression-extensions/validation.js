import { i18n } from "discourse-i18n";

export function buildValidation({ cmLanguage, cmLint }) {
  const { syntaxTree } = cmLanguage;
  const { linter } = cmLint;

  return linter(
    ({ state }) => {
      const diagnostics = [];

      syntaxTree(state).iterate({
        enter(node) {
          if (
            node.name === "Expression" &&
            !state.doc.sliceString(node.from, node.to).endsWith("}}")
          ) {
            diagnostics.push({
              from: node.from,
              to: state.doc.length,
              severity: "error",
              message: i18n(
                "discourse_workflows.expression_language.unclosed_expression"
              ),
              markClass: "cm-wf-error",
            });
          }
        },
      });

      return diagnostics;
    },
    {
      // Flag an unclosed expression as soon as it's typed, not after a pause.
      delay: 0,
      // Long values are parsed in stages; recheck as more of the tree arrives.
      needsRefresh: (update) =>
        syntaxTree(update.startState) !== syntaxTree(update.state),
    }
  );
}
