import stylelint from "stylelint";
import parser from "postcss-selector-parser";

const ruleName = "discourse/uc-classes-in-where";

// `.uc-*` classes are the `uc-<dasherized-setting-name>` body classes emitted
// for upcoming changes (feature flags with `include_css: true`). They gate
// transitional CSS for a change and are removed once it becomes permanent, so
// they must never contribute specificity: every use has to sit inside a
// `:where()` clause. This keeps the styling safe to unwrap and delete later
// without leaving behind rules that silently relied on the class's specificity.
//
// A `.uc-*` class is allowed only when one of its ancestor nodes is a
// `:where()` pseudo-class.
function isInsideWhere(node) {
  for (let parent = node.parent; parent; parent = parent.parent) {
    if (parent.type === "pseudo" && parent.value.toLowerCase() === ":where") {
      return true;
    }
  }
  return false;
}

export default stylelint.createPlugin(ruleName, (primaryOption) => {
  return (root, result) => {
    if (!primaryOption) {
      return;
    }

    root.walkRules((rule) => {
      parser((selectors) => {
        selectors.walkClasses((classNode) => {
          if (!classNode.value.startsWith("uc-") || isInsideWhere(classNode)) {
            return;
          }

          stylelint.utils.report({
            message: `Wrap the upcoming-change class ".${classNode.value}" in a :where() clause so it does not contribute specificity`,
            node: rule,
            result,
            ruleName,
            word: "." + classNode.value,
          });
        });
      }).processSync(rule.selector);
    });
  };
});
