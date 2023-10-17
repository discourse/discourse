const eslint = require("eslint-config-discourse/eslint");

const config = { ...eslint };
config.rules = {
  ...config.rules,
  "discourse-ember/global-ember": "error",
  "eol-last": "error",
  "no-restricted-globals": "off",
};

module.exports = config;
