const KEY = "discourse__dev_tools";

export default {
  initialize(app) {
    window.enableDevTools = () => {
      window.localStorage.setItem(KEY, "true");
      window.location.reload();
    };

    window.disableDevTools = () => {
      window.localStorage.removeItem(KEY);
      window.location.reload();
    };

    if (window.localStorage.getItem(KEY)) {
      // eslint-disable-next-line no-console
      console.log("Loading Discourse dev tools...");

      app.deferReadiness();

      import("discourse/static/dev-tools/entrypoint").then((devTools) => {
        devTools.init();

        // eslint-disable-next-line no-console
        console.log(
          "Loaded Discourse dev tools. Run `disableDevTools()` in console to disable."
        );

        app.advanceReadiness();
      });
    }
  },
};
