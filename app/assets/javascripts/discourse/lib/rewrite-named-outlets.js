module.exports = function () {
  return {
    name: "rewrite-named-outlets",
    visitor: {
      MustacheStatement: (node) => {
        if (
          node.path.type === "PathExpression" &&
          node.path.original === "outlet" &&
          node.params[0]
        ) {
          node.path.type = "StringLiteral";
          node.path.value =
            node.path.original = `(named outlet ${node.params[0].value} - unable to render under Ember 4.x)`;
          node.params.length = 0;
        }
      },
    },
  };
};
