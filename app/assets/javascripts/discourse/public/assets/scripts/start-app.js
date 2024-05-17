document.addEventListener("discourse-init", (e) => {
  performance.mark("discourse-init");
  const config = e.detail;
  const app = require(`${config.modulePrefix}/app`)["default"].create(config);
  app.start();
});
