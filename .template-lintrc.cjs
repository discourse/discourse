const templateLint = require("@discourse/lint-configs/template-lint");

module.exports = {
  ...templateLint,
  rules: {
    ...templateLint.rules,
    "no-capital-arguments": false, // @args is used for MountWidget
    "require-button-type": false,
    "no-action": true,
    "require-strict-mode": true,
  },
};
