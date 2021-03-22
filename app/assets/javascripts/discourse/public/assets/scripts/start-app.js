document.addEventListener("discourse-booted", (e) => {
  const config = e.detail;
  const app = require(`${config.modulePrefix}/app`)["default"].create(config);
  app.start();
});
