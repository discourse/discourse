document.addEventListener("discourse-init", async (e) => {
  performance.mark("discourse-init");
  const config = e.detail;
  const klass = require(`${config.modulePrefix}/app`).default;
  // load themes
  window.themeInitializers = [
    /*
    { "initializer/1": module,
      "initializer/2": module,
      ...
    }
    */
  ];
  for (const link of document.querySelectorAll("link[rel=modulepreload]")) {
    const mod = await import(link.href);
    window.themeInitializers.push(mod.initializers);
  }
  const app = klass.create(config);
  app.start();
});
