document.addEventListener("discourse-init", async (e) => {
  performance.mark("discourse-init");
  const config = e.detail;
  const { default: klass, loadThemes, loadAdmin } = require(
    `${config.modulePrefix}/app`
  );

  if (
    document.querySelector(
      'link[rel="preload"][data-discourse-entrypoint="admin"]'
    )
  ) {
    await loadAdmin();
  }
  await loadThemes();

  const app = klass.create(config);
  app.start();
});
