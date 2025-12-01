import App, { loadAdmin, loadThemes } from "discourse/app";

document.addEventListener("discourse-init", async (e) => {
  performance.mark("discourse-init");
  const config = e.detail;

  // if (
  //   document.querySelector(
  //     'link[rel="preload"][data-discourse-entrypoint="admin"]'
  //   )
  // ) {
  await loadAdmin();
  // }

  await loadThemes();

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
