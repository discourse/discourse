const config = require("@discourse/lint-configs/eslint");

config.rules["ember/no-classic-classes"] = "error";

module.exports = config;
