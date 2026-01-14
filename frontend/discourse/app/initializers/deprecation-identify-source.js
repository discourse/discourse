import { registerDeprecationHandler } from "@ember/debug";
import { consolePrefix } from "discourse/lib/source-identifier";

let registered = false;

export default {
  initialize() {
    if (registered) {
      return;
    }

    registerDeprecationHandler((message, options, next) => {
      let prefix = consolePrefix();
      if (prefix) {
        next(`${prefix} ${message}`, options);
      } else {
        next(message, options);
      }
    });

    registered = true;
  },
};
