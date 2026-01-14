import { registerDeprecationHandler } from "@ember/debug";
import { consolePrefix, getThemeInfo } from "discourse/lib/source-identifier";

let registered = false;
const seenMessages = new Set();

export default {
  initialize() {
    if (registered) {
      return;
    }

    registerDeprecationHandler((message, options, next) => {
      if (options.id !== "ember-this-fallback.this-property-fallback") {
        next(message, options);
        return;
      }

      // These errors don't have useful backtraces, but we can parse theme/plugin
      // info from the message itself.
      const pluginMatch = message.match(/\/plugins\/([\w-]+)\//)?.[1];
      const themeIdMatch = message.match(/\/theme-(\d+)\//)?.[1];

      if (pluginMatch || themeIdMatch) {
        const source = {
          type: pluginMatch ? "plugin" : "theme",
          name: pluginMatch || getThemeInfo(parseInt(themeIdMatch, 10)).name,
          id: themeIdMatch,
        };
        options.source = source;
        message = `${consolePrefix(null, source)} ${message}`;
      }

      // Only print each message once, to avoid flood of console noise
      if (seenMessages.has(message)) {
        return;
      }
      seenMessages.add(message);
      options.url = "https://meta.discourse.org/t/337276";
      next(message, options);
    });

    registered = true;
  },
};
