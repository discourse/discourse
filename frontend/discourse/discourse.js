import App, { loadAdmin, loadThemesAndPlugins } from "discourse/app";

(async function () {
  if (window.unsupportedBrowser) {
    throw "Unsupported browser detected";
  }

  let element = document.querySelector(
    `meta[name="discourse/config/environment"]`
  );
  const config = JSON.parse(
    decodeURIComponent(element.getAttribute("content"))
  );

  performance.mark("discourse-init");

  if (document.querySelector('#data-discourse-setup[data-is-staff="true"]')) {
    await loadAdmin();
  }

  await loadThemesAndPlugins();

  const app = App.create(config.detail);
  app.start();
})();
