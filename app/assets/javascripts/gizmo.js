/* eslint-disable no-console */
/* global rails */

globalThis.window = {};
globalThis.console = {
  prefix: "[DiscourseJsProcessor] ",
  log(...args) {
    rails.logger.info(console.prefix + args.join(" "));
  },
  warn(...args) {
    rails.logger.warn(console.prefix + args.join(" "));
  },
  error(...args) {
    rails.logger.error(console.prefix + args.join(" "));
  },
};

const processor = require("./discourse-js-processor");

// Make interfaces available via `v8.call`
globalThis.compileRawTemplate = processor.compileRawTemplate;
globalThis.transpile = processor.transpile;
globalThis.minify = processor.minify;
globalThis.getMinifyResult = processor.getMinifyResult;
