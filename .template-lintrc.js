const templateLint = require("@discourse/lint-configs/template-lint");

module.exports = {
  ...templateLint,
  rules: {
    ...templateLint.rules,
    "no-capital-arguments": false, // TODO: we extensively use `args` argument name
    "require-button-type": false,
  },

  // https://github.com/ember-template-lint/ember-template-lint/pull/2982
  overrides: [
    {
      files: ["**/*.gjs", "**/*.gts"],
      rules: {
        "modifier-name-case": "off",
      },
    },
  ],
};
