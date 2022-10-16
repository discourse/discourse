import {
  isDevelopment,
  isProduction,
  isTesting,
  setEnvironment,
} from "discourse-common/config/environment";
import { setupS3CDN, setupURL } from "discourse-common/lib/get-url";
import I18n from "I18n";
import PreloadStore from "discourse/lib/preload-store";
import RSVP from "rsvp";
import Session from "discourse/models/session";
import { setDefaultOwner } from "discourse-common/lib/get-owner";
import { setIconList } from "discourse-common/lib/icon-library";
import { setURLContainer } from "discourse/lib/url";
import runloop from "@ember/runloop";
import { DEBUG } from "@glimmer/env";

export default {
  name: "discourse-bootstrap",

  // The very first initializer to run
  initialize(container) {
    if (DEBUG) {
      runloop._backburner.ASYNC_STACKS = true;
    }

    setURLContainer(container);
    setDefaultOwner(container);

    // Our test environment has its own bootstrap code
    if (isTesting()) {
      return;
    }

    let setupData;
    const setupDataElement = document.getElementById("data-discourse-setup");
    if (setupDataElement) {
      setupData = setupDataElement.dataset;
    }

    let preloaded;
    const preloadedDataElement = document.getElementById("data-preloaded");
    if (preloadedDataElement) {
      preloaded = JSON.parse(preloadedDataElement.dataset.preloaded);
    }

    const keys = Object.keys(preloaded);
    if (keys.length === 0) {
      throw "No preload data found in #data-preloaded. Unable to boot Discourse.";
    }

    keys.forEach(function (key) {
      PreloadStore.store(key, JSON.parse(preloaded[key]));

      if (setupData.debugPreloadedAppData === "true") {
        // eslint-disable-next-line no-console
        console.log(key, PreloadStore.get(key));
      }
    });

    setupURL(setupData.cdn, setupData.baseUrl, setupData.baseUri);
    setEnvironment(setupData.environment);
    I18n.defaultLocale = setupData.defaultLocale;

    window.Logster = window.Logster || {};
    window.Logster.enabled = setupData.enableJsErrorReporting === "true";

    let session = Session.current();
    session.serviceWorkerURL = setupData.serviceWorkerUrl;
    session.assetVersion = setupData.assetVersion;
    session.disableCustomCSS = setupData.disableCustomCss === "true";
    session.markdownItURL = setupData.markdownItUrl;

    if (setupData.mbLastFileChangeId) {
      session.mbLastFileChangeId = parseInt(setupData.mbLastFileChangeId, 10);
    }

    if (setupData.safeMode) {
      session.safe_mode = setupData.safeMode;
    }

    session.darkModeAvailable =
      document.querySelectorAll('link[media="(prefers-color-scheme: dark)"]')
        .length > 0;

    session.defaultColorSchemeIsDark = setupData.colorSchemeIsDark === "true";

    session.highlightJsPath = setupData.highlightJsPath;
    session.svgSpritePath = setupData.svgSpritePath;
    session.userColorSchemeId =
      parseInt(setupData.userColorSchemeId, 10) || null;
    session.userDarkSchemeId = parseInt(setupData.userDarkSchemeId, 10) || -1;

    let iconList = setupData.svgIconList;
    if (isDevelopment() && iconList) {
      setIconList(
        typeof iconList === "string" ? JSON.parse(iconList) : iconList
      );
    }

    if (setupData.s3BaseUrl) {
      setupS3CDN(setupData.s3BaseUrl, setupData.s3Cdn);
    }

    RSVP.configure("onerror", function (e) {
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
  },
};
