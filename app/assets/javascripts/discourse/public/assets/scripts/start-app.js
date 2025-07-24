document.addEventListener("discourse-init", async (e) => {
  performance.mark("discourse-init");
  const config = e.detail;
  const { default: klass, loadThemes } = require(`${config.modulePrefix}/app`);

  await loadThemes();

  const app = klass.create(config);
  app.start();
});
