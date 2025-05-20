document.addEventListener("discourse-init", async (e) => {
  performance.mark("discourse-init");
  const config = e.detail;
  const klass = require(`${config.modulePrefix}/app`).default;

  for (const link of document.querySelectorAll("link[rel=modulepreload]")) {
    const themeId = link.dataset.themeId;
    const compatModules = (await import(link.href)).default;
    for (const [key, mod] of Object.entries(compatModules)) {
      define(`discourse/theme-${themeId}/${key}`, () => mod);
    }
  }

  const app = klass.create(config);
  app.start();
});
