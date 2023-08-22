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

import {
  compileRawTemplate,
  getMinifyResult,
  minify,
  transpile,
} from "./discourse-js-processor";

// Make interfaces available via `v8.call`
globalThis.compileRawTemplate = compileRawTemplate;
globalThis.transpile = transpile;
globalThis.minify = minify;
globalThis.getMinifyResult = getMinifyResult;
