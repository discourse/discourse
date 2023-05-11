const SILENCED_WARN_PREFIXES = [
  "Setting the `jquery-integration` optional feature flag",
  "The Ember Classic edition has been deprecated",
  "Setting the `template-only-glimmer-components` optional feature flag to `false`",
  "DEPRECATION: Invoking the `<LinkTo>` component with positional arguments is deprecated",
];

let consoleWarnSilenced = false;

module.exports = class DeprecationSilencer {
  static silenceUiWarn(ui) {
    const oldWriteWarning = ui.writeWarnLine.bind(ui);
    ui.writeWarnLine = (message, ...args) => {
      if (
        !SILENCED_WARN_PREFIXES.some((prefix) => message.startsWith(prefix))
      ) {
        return oldWriteWarning(message, ...args);
      }
    };
  }

  static silenceConsoleWarn() {
    if (consoleWarnSilenced) {
      return;
    }
    /* eslint-disable no-console */
    const oldConsoleWarn = console.warn.bind(console);
    console.warn = (message, ...args) => {
      if (
        !SILENCED_WARN_PREFIXES.some((prefix) => message.startsWith(prefix))
      ) {
        return oldConsoleWarn(message, ...args);
      }
    };
    /* eslint-enable no-console */
    consoleWarnSilenced = true;
  }

  /**
   * Generates a dummy babel plugin which applies the console.warn silences in worker
   * processes. Does not actually affect babel output.
   */
  static generateBabelPlugin() {
    return {
      _parallelBabel: {
        requireFile: require.resolve("./deprecation-silencer"),
        buildUsing: "babelShim",
      },
    };
  }

  static babelShim() {
    DeprecationSilencer.silenceConsoleWarn();
    return {};
  }
};
