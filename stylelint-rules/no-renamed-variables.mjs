import { readFileSync } from "node:fs";
import valueParser from "postcss-value-parser";
import stylelint from "stylelint";

const renames = JSON.parse(
  readFileSync(
    new URL("../app/assets/stylesheets/variable-renames.json", import.meta.url)
  )
);

const ruleName = "discourse/no-renamed-variables";
const messages = stylelint.utils.ruleMessages(ruleName, {
  renamed: (oldName, newName) => `"${oldName}" was renamed to "${newName}"`,
});

const ruleFunction = (primaryOption) => {
  return (root, result) => {
    if (!primaryOption) {
      return;
    }

    root.walkDecls((decl) => {
      const newProp = renames[decl.prop];
      if (newProp) {
        stylelint.utils.report({
          message: messages.renamed(decl.prop, newProp),
          node: decl,
          result,
          ruleName,
          word: decl.prop,
          fix: () => (decl.prop = newProp),
        });
      }

      const parsed = valueParser(decl.value);
      parsed.walk((node) => {
        const newName = node.type === "word" && renames[node.value];
        if (newName) {
          stylelint.utils.report({
            message: messages.renamed(node.value, newName),
            node: decl,
            result,
            ruleName,
            word: node.value,
            fix: () => {
              node.value = newName;
              decl.value = parsed.toString();
            },
          });
        }
      });
    });
  };
};

ruleFunction.ruleName = ruleName;
ruleFunction.messages = messages;
ruleFunction.meta = { fixable: true };

export default stylelint.createPlugin(ruleName, ruleFunction);
