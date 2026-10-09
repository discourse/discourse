/* global rails */

import "core-js/actual/url";
import { TextDecoder, TextEncoder } from "fastestsmallesttextencoderdecoder";
import path from "path";
import getRandomValues from "polyfill-crypto.getrandomvalues";
import BindingsWasm from "./node_modules/@rollup/browser/dist/bindings_wasm_bg.wasm";

const CONSOLE_PREFIX = "[AssetProcessor] ";
globalThis.window = {};
globalThis.console = {
  debug(...args) {
    rails.logger.info(CONSOLE_PREFIX + args.join(" "));
  },
  info(...args) {
    rails.logger.info(CONSOLE_PREFIX + args.join(" "));
  },
  log(...args) {
    rails.logger.info(CONSOLE_PREFIX + args.join(" "));
  },
  warn(...args) {
    rails.logger.warn(CONSOLE_PREFIX + args.join(" "));
  },
  error(...args) {
    rails.logger.error(CONSOLE_PREFIX + args.join(" "));
  },
};

globalThis.TextEncoder = TextEncoder;
globalThis.TextDecoder = TextDecoder;

path.win32 = {
  sep: "/",
};

globalThis.crypto = { getRandomValues };

globalThis.fetch = function (url) {
  if (url.toString() === "http://example.com/bindings_wasm_bg.wasm") {
    return new Promise((resolve) => resolve(BindingsWasm));
  }
  throw "fetch not implemented";
};
