const eslint = require("@discourse/lint-configs/eslint");

const config = { ...eslint };
config.rules = {
  ...config.rules,
  // "no-restricted-globals": "off",
};

module.exports = config;
