const templateLint = require("@discourse/lint-configs/template-lint");

const config = {
  ...templateLint,
  rules: {
    ...templateLint.rules,
    "no-capital-arguments": false, // TODO: we extensively use `args` argument name
    "require-button-type": false,
  },
};

module.exports = config;
