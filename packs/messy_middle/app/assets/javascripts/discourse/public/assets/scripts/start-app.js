document.addEventListener("discourse-booted", (e) => {
  performance.mark("discourse-booted");
  const config = e.detail;
  const app = require(`${config.modulePrefix}/app`)["default"].create(config);
  app.start();
});
