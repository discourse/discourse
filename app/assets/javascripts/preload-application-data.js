(function() {
  var ps = require("preload-store").default;
  var preloadedDataElement = document.getElementById("data-preloaded");

  if (preloadedDataElement) {
    var preloaded = JSON.parse(preloadedDataElement.dataset.preloaded);

    Object.keys(preloaded).forEach(function(key) {
      ps.store(key, JSON.parse(preloaded[key]));
    });
  }

  var setupData = document.getElementById("data-discourse-setup").dataset;

  Discourse.CDN = setupData.cdn;
  Discourse.BaseUrl = setupData.baseUrl;
  Discourse.BaseUri = setupData.baseUri;
  Discourse.Environment = setupData.environment;
  Discourse.SiteSettings = ps.get("siteSettings");
  Discourse.ThemeSettings = ps.get("themeSettings");
  Discourse.LetterAvatarVersion = setupData.letterAvatarVersion;
  Discourse.MarkdownItURL = setupData.markdownItUrl;
  Discourse.ServiceWorkerURL = setupData.serviceWorkerUrl;
  I18n.defaultLocale = setupData.defaultLocale;
  Discourse.start();
  Discourse.set("assetVersion", setupData.assetVersion);
  Discourse.Session.currentProp(
    "disableCustomCSS",
    setupData.disableCustomCss === "true"
  );

  if (setupData.safeMode) {
    Discourse.Session.currentProp("safe_mode", setupData.safeMode);
  }

  Discourse.HighlightJSPath = setupData.highlightJsPath;

  if (setupData.s3BaseUrl) {
    Discourse.S3CDN = setupData.s3Cdn;
    Discourse.S3BaseUrl = setupData.s3BaseUrl;
  }
})();
