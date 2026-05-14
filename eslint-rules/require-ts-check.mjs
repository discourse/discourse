/**
 * Requires `// @ts-check` to be the first comment in the file.
 *
 * Scoped via `files:` overrides in `eslint.config.mjs` so it only fires for
 * directories where we want strict JSDoc type checking. Outside those
 * directories the rule is unregistered and never runs.
 *
 * Why "first comment" rather than "first line": TypeScript only honors
 * `// @ts-check` when it appears before any non-comment code. Putting it
 * lower in the file is silently a no-op, so we want a hard error if it's
 * missing or misplaced.
 */

const TS_CHECK = "@ts-check";

export default {
  meta: {
    type: "problem",
    docs: {
      description:
        "Require `// @ts-check` as the first comment of the file so TypeScript actually checks the JSDoc types.",
    },
    schema: [],
    messages: {
      missing:
        "Files in this directory must start with `// @ts-check` so the JSDoc types are actually checked.",
      misplaced:
        "`// @ts-check` must be the first comment in the file. TypeScript ignores it when other code or comments appear above it.",
    },
  },
  create(context) {
    return {
      Program(node) {
        const sourceCode = context.sourceCode ?? context.getSourceCode();
        const comments = sourceCode.getAllComments();
        const firstComment = comments[0];

        const hasTsCheck = comments.some(
          (c) => c.type === "Line" && c.value.trim() === TS_CHECK
        );

        if (!hasTsCheck) {
          context.report({ node, messageId: "missing" });
          return;
        }

        if (
          !firstComment ||
          firstComment.type !== "Line" ||
          firstComment.value.trim() !== TS_CHECK
        ) {
          context.report({
            node: firstComment ?? node,
            messageId: "misplaced",
          });
        }
      },
    };
  },
};
