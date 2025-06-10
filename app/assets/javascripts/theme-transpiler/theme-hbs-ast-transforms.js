function manipulateAstNodeForTheme(node, themeId) {
  // Magically add theme id as the first param for each of these helpers)
  if (
    node.path.parts &&
    ["theme-i18n", "theme-prefix", "theme-setting"].includes(node.path.parts[0])
  ) {
    if (node.params.length === 1) {
      node.params.unshift({
        type: "NumberLiteral",
        value: themeId,
        original: themeId,
        loc: { start: {}, end: {} },
      });
    }
  }
}

export default function buildEmberTemplateManipulatorPlugin(themeId) {
  return function () {
    return {
      name: "theme-template-manipulator",
      visitor: {
        SubExpression: (node) => manipulateAstNodeForTheme(node, themeId),
        MustacheStatement: (node) => manipulateAstNodeForTheme(node, themeId),
      },
    };
  };
}
