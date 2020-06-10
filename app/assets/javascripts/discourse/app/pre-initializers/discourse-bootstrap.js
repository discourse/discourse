import PreloadStore from "discourse/lib/preload-store";
import I18n from "I18n";
import Session from "discourse/models/session";
import RSVP from "rsvp";
import {
  setEnvironment,
  isTesting,
  isProduction
} from "discourse-common/config/environment";
import { setupURL, setupS3CDN } from "discourse-common/lib/get-url";
import deprecated from "discourse-common/lib/deprecated";

export default {
  name: "discourse-bootstrap",

  // The very first initializer to run
  initialize(container, app) {
    // Our test environment has its own bootstrap code
    if (isTesting()) {
      return;
    }
    const preloadedDataElement = document.getElementById("data-preloaded");
    const setupData = document.getElementById("data-discourse-setup").dataset;

    if (preloadedDataElement) {
      const preloaded = JSON.parse(preloadedDataElement.dataset.preloaded);

      Object.keys(preloaded).forEach(function(key) {
        PreloadStore.store(key, JSON.parse(preloaded[key]));

        if (setupData.debugPreloadedAppData === "true") {
          /* eslint-disable no-console */
          console.log(key, PreloadStore.get(key));
          /* eslint-enable no-console */
        }
      });
    }

    app.CDN = setupData.cdn;

    let baseUrl = setupData.baseUrl;
    Object.defineProperty(app, "BaseUrl", {
      get() {
        deprecated(`use "get-url" helpers instead of Discourse.BaseUrl`, {
          since: "2.5",
          dropFrom: "2.6"
        });
        return baseUrl;
      }
    });
    let baseUri = setupData.baseUri;
    Object.defineProperty(app, "BaseUri", {
      get() {
        deprecated(`use "get-url" helpers instead of Discourse.BaseUri`, {
          since: "2.5",
          dropFrom: "2.6"
        });
        return baseUri;
      }
    });
    setupURL(setupData.cdn, baseUrl, setupData.baseUri);
    setEnvironment(setupData.environment);
    app.SiteSettings = PreloadStore.get("siteSettings");
    app.ThemeSettings = PreloadStore.get("themeSettings");
    app.LetterAvatarVersion = setupData.letterAvatarVersion;
    app.MarkdownItURL = setupData.markdownItUrl;
    app.ServiceWorkerURL = setupData.serviceWorkerUrl;
    I18n.defaultLocale = setupData.defaultLocale;

    window.Logster = window.Logster || {};
    window.Logster.enabled = setupData.enableJsErrorReporting === "true";

    app.set("assetVersion", setupData.assetVersion);

    Session.currentProp(
      "disableCustomCSS",
      setupData.disableCustomCss === "true"
    );

    if (setupData.safeMode) {
      Session.currentProp("safe_mode", setupData.safeMode);
    }

    app.HighlightJSPath = setupData.highlightJsPath;
    app.SvgSpritePath = setupData.svgSpritePath;

    if (app.Environment === "development") {
      app.SvgIconList = setupData.svgIconList;
    }

    if (setupData.s3BaseUrl) {
      app.S3CDN = setupData.s3Cdn;
      app.S3BaseUrl = setupData.s3BaseUrl;
      setupS3CDN(setupData.s3BaseUrl, setupData.s3Cdn);
    }

    RSVP.configure("onerror", function(e) {
      // Ignore TransitionAborted exceptions that bubble up
      if (e && e.message === "TransitionAborted") {
        return;
      }

      if (!isProduction()) {
        /* eslint-disable no-console  */
        if (e) {
          if (e.message || e.stack) {
            console.log(e.message);
            console.log(e.stack);
          } else {
            console.log("Uncaught promise: ", e);
          }
        } else {
          console.log("A promise failed but was not caught.");
        }
        /* eslint-enable no-console  */
      }

      window.onerror(e && e.message, null, null, null, e);
    });
  }
};
