import stylelint from "stylelint";

const blocked = [
  /--primary(-.*)?/,
  /--secondary(-.*)?/,
  /--tertiary(-.*)?/,
  /--quarternary(-.*)?/,
];

const varRegex = /var\(\s*(--[^,)]+)/g;

export default stylelint.createPlugin(
  "discourse/no-core-color-variables",
  (primaryOption) => {
    return (root, result) => {
      if (!primaryOption) {
        return;
      }

      root.walkDecls((decl) => {
        const value = decl.value;
        if (!value.includes("var(")) {
          return;
        }

        let match;
        while ((match = varRegex.exec(value)) !== null) {
          const varName = match[1].trim();

          for (const pattern of blocked) {
            if (pattern.test(varName)) {
              stylelint.utils.report({
                message:
                  "Do not use core color variables directly. Use var(--token-*) design tokens instead",
                node: decl,
                result,
                ruleName: "discourse/no-core-color-variables",
                word: varName,
              });
              break;
            }
          }
        }

        varRegex.lastIndex = 0;
      });
    };
  }
);
