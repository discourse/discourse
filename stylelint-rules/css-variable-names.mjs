import { readFileSync } from "node:fs";
import valueParser from "postcss-value-parser";
import stylelint from "stylelint";
import createGrammar from "../frontend/asset-processor/css-variable-grammar.mjs";

const readJson = (path) =>
  JSON.parse(readFileSync(new URL(path, import.meta.url)));
const parse = createGrammar(
  readJson("../app/assets/stylesheets/variable-vocabulary.json")
);
const baseLayer = readJson(
  "../app/assets/stylesheets/variable-base-layer.json"
);
const splitNames = Object.keys(baseLayer).filter(
  (name) => baseLayer[name] === "split"
);

const ruleName = "discourse/css-variable-names";
const messages = stylelint.utils.ruleMessages(ruleName, {
  scheme: (name, reason) =>
    `"${name}" does not follow the CSS variable naming scheme. ${reason}`,
  split: (name) =>
    `"${name}" is a base variable with several jobs, read the token for this use instead`,
});

const errorsFor = new Map();
function schemeErrors(name) {
  if (!errorsFor.has(name)) {
    errorsFor.set(name, parse(name).errors);
  }
  return errorsFor.get(name);
}

const ruleFunction = (primaryOption) => {
  return (root, result) => {
    if (!primaryOption) {
      return;
    }

    const checkReads = (node, text) => {
      if (!splitNames.some((name) => text.includes(name))) {
        return;
      }
      valueParser(text).walk((value) => {
        const name =
          value.type === "function" &&
          value.value === "var" &&
          value.nodes[0]?.value;
        if (baseLayer[name] === "split") {
          stylelint.utils.report({
            message: messages.split(name),
            node,
            result,
            ruleName,
            word: name,
          });
        }
      });
    };

    root.walkDecls((decl) => {
      if (!decl.prop.startsWith("--")) {
        checkReads(decl, decl.value);
        return;
      }
      if (Object.hasOwn(baseLayer, decl.prop)) {
        return;
      }
      const [reason] = schemeErrors(decl.prop);
      if (reason) {
        stylelint.utils.report({
          message: messages.scheme(decl.prop, reason),
          node: decl,
          result,
          ruleName,
          word: decl.prop,
        });
      }
    });
    root.walkAtRules((atRule) => checkReads(atRule, atRule.params));
  };
};

ruleFunction.ruleName = ruleName;
ruleFunction.messages = messages;

export default stylelint.createPlugin(ruleName, ruleFunction);
