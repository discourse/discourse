"use strict";

const commonBabelConfig = require("../discourse/lib/common-babel-config");

module.exports = {
  name: require("./package").name,
  options: {
    ...commonBabelConfig(),
  },
  isDevelopingAddon() {
    return true;
  },
};
