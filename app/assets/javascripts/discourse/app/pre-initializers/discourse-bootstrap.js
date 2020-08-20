import PreloadStore from "discourse/lib/preload-store";
import I18n from "I18n";
import Session from "discourse/models/session";
import RSVP from "rsvp";
import {
  setEnvironment,
  isTesting,
  isProduction,
  isDevelopment
} from "discourse-common/config/environment";
import { setupURL, setupS3CDN } from "discourse-common/lib/get-url";
import deprecated from "discourse-common/lib/deprecated";
import { setIconList } from "discourse-common/lib/icon-library";
import { setPluginContainer } from "discourse/lib/plugin-api";

export default {
  name: "discourse-bootstrap",

  // The very first initializer to run
  initialize(container, app) {
    setPluginContainer(container);

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
    I18n.defaultLocale = setupData.defaultLocale;

    window.Logster = window.Logster || {};
    window.Logster.enabled = setupData.enableJsErrorReporting === "true";

    let session = Session.current();
    session.serviceWorkerURL = setupData.serviceWorkerUrl;
    session.assetVersion = setupData.assetVersion;
    session.disableCustomCSS = setupData.disableCustomCss === "true";
    session.markdownItURL = setupData.markdownItUrl;

    if (setupData.safeMode) {
      session.safe_mode = setupData.safeMode;
    }

    session.darkModeAvailable =
      document.head.querySelectorAll(
        'link[media="(prefers-color-scheme: dark)"]'
      ).length > 0;

    session.darkColorScheme =
      !window.matchMedia("(prefers-color-scheme: dark)").matches &&
      getComputedStyle(document.documentElement)
        .getPropertyValue("--scheme-type")
        .trim() === "dark";

    session.highlightJsPath = setupData.highlightJsPath;
    session.svgSpritePath = setupData.svgSpritePath;

    if (isDevelopment()) {
      setIconList(setupData.svgIconList);
    }

    if (setupData.s3BaseUrl) {
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
