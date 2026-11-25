import { readFileSync } from "node:fs";
import stylelint from "stylelint";
import rewriteRgbTwins from "../frontend/asset-processor/rgb-twin-rewriter.mjs";

const twins = JSON.parse(
  readFileSync(
    new URL(
      "../app/assets/stylesheets/variable-rgb-twins.json",
      import.meta.url
    )
  )
);
const twinNames = Object.keys(twins);

const ruleName = "discourse/no-deprecated-rgb-variables";
const messages = stylelint.utils.ruleMessages(ruleName, {
  rewritable: (twin, color) =>
    `"${twin}" is deprecated, use color-mix() with "${color}"`,
  manual: (twin, color) =>
    `"${twin}" is deprecated and this use cannot be rewritten automatically, use "${color}" instead`,
});

const ruleFunction = (primaryOption) => {
  return (root, result) => {
    if (!primaryOption) {
      return;
    }

    const check = (node, key) => {
      if (!twinNames.some((twin) => node[key].includes(twin))) {
        return;
      }

      const { value, rewritten, remaining } = rewriteRgbTwins(node[key], twins);
      for (const twin of rewritten) {
        stylelint.utils.report({
          message: messages.rewritable(twin, twins[twin]),
          node,
          result,
          ruleName,
          word: twin,
          fix: () => (node[key] = value),
        });
      }
      for (const twin of remaining) {
        stylelint.utils.report({
          message: messages.manual(twin, twins[twin]),
          node,
          result,
          ruleName,
          word: twin,
          severity: "warning",
        });
      }
    };

    root.walkDecls((decl) => check(decl, "value"));
    root.walkAtRules((atRule) => check(atRule, "params"));
  };
};

ruleFunction.ruleName = ruleName;
ruleFunction.messages = messages;
ruleFunction.meta = { fixable: true };

export default stylelint.createPlugin(ruleName, ruleFunction);
