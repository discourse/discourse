/* global rails */

import "core-js/actual/url";
import { TextDecoder, TextEncoder } from "fastestsmallesttextencoderdecoder";
import path from "path";
import getRandomValues from "polyfill-crypto.getrandomvalues";

const CONSOLE_PREFIX = "[DiscourseJsProcessor] ";
globalThis.window = {};
globalThis.console = {
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
