import App, { loadAdmin, loadThemesAndPlugins } from "discourse/app";

document.addEventListener("discourse-init", async (e) => {
  performance.mark("discourse-init");
  const config = e.detail;

  if (document.querySelector('#data-discourse-setup[data-is-staff="true"]')) {
    await loadAdmin();
  }

  await loadThemesAndPlugins();

  const app = App.create(config);
  app.start();
});

(function () {
  if (window.unsupportedBrowser) {
    throw "Unsupported browser detected";
  }

  let element = document.querySelector(
    `meta[name="discourse/config/environment"]`
  );
  const config = JSON.parse(
    decodeURIComponent(element.getAttribute("content"))
  );
  const event = new CustomEvent("discourse-init", { detail: config });
  document.dispatchEvent(event);
})();
