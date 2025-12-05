/**
 * @returns {import('@glimmer/syntax').ASTPlugin}
 */
module.exports = function (env) {
  const stripWhitespaceStack = [];
  /** @type {import('@glimmer/syntax').ASTPluginBuilder} */
  const b = env.syntax.builders;

  return {
    name: "theme-template-manipulator",
    visitor: {
      BlockStatement: {
        enter(node) {
          if (node.path.original === "stripWhitespace") {
            stripWhitespaceStack.push(true);
          }
        },
        exit(node) {
          if (node.path.original === "stripWhitespace") {
            stripWhitespaceStack.pop();

            // Add a call to checkStripWhitespace to verify correct usage
            let checkStripWhitespace = env.meta.jsutils.bindImport(
              "discourse/helpers/strip-whitespace",
              "_checkStripWhitespace",
              node,
              {
                nameHint: "checkStripWhitespace",
              }
            );

            node.program.body.push(
              b.mustache(b.path(checkStripWhitespace), [
                b.path(node.path.head.name),
              ])
            );

            // Unwrap the block
            return node.program.body;
          }
        },
      },
      TextNode(node) {
        if (stripWhitespaceStack.length > 0) {
          node.chars = node.chars.trim();
          if (node.chars === "") {
            return null;
          }
        }
      },
    },
  };
};
