import deprecated from "discourse/lib/deprecated";
import { isRailsTesting, isTesting } from "discourse/lib/environment";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import Mobile from "discourse/lib/mobile";
import TrackedMediaQuery from "discourse/lib/tracked-media-query";

const APPLE_NAVIGATOR_PLATFORMS = /iPhone|iPod|iPad|Macintosh|MacIntel/;
const APPLE_USER_AGENT_DATA_PLATFORM = /macOS/;

const ua = navigator.userAgent;

const anyPointerCourseQuery = new TrackedMediaQuery("(any-pointer: coarse)");

let siteInitialized = false;

class Capabilities {
  isAndroid = ua.includes("Android");
  isWinphone = ua.includes("Windows Phone");
  isIpadOS = ua.includes("Mac OS") && !/iPhone|iPod/.test(ua) && this.touch;
  isIOS = (/iPhone|iPod/.test(ua) || this.isIpadOS) && !window.MSStream;
  isApple =
    APPLE_NAVIGATOR_PLATFORMS.test(navigator.platform) ||
    (navigator.userAgentData &&
      APPLE_USER_AGENT_DATA_PLATFORM.test(navigator.userAgentData.platform));

  isOpera = !!window.opera || ua.includes(" OPR/");
  isFirefox = ua.includes("Firefox");
  isChrome = !!window.chrome && !this.isOpera;
  // In iframes, Safari-specific objects aren't accessible, so fall back to UA detection
  isSafari =
    window.self !== window.top
      ? ua.includes("Safari") &&
        !ua.includes("Chrome") &&
        !ua.includes("Chromium")
      : /Constructor/.test(window.HTMLElement) ||
        window.safari?.pushNotification?.toString() ===
          "[object SafariRemoteNotification]";

  hasContactPicker = "contacts" in navigator && "ContactsManager" in window;

  canVibrate = "vibrate" in navigator;

  isPwa =
    window.matchMedia("(display-mode: standalone)").matches ||
    window.navigator.standalone ||
    document.referrer.includes("android-app://");
  isiOSPWA = this.isPwa && this.isIOS;

  wasLaunchedFromDiscourseHub =
    window.location.search.includes("discourse_app=1");
  isAppWebview = window.ReactNativeWebView !== undefined;

  /**
   * Defines the responsive viewport breakpoints and their media queries.
   * Reduces the breakpoint entries into viewport properties that can be accessed
   * to check if each breakpoint matches the current viewport size.
   *
   * @type {Object.<string, boolean>}
   * @property {boolean} sm - True if viewport width is at least 40rem
   * @property {boolean} md - True if viewport width is at least 48rem
   * @property {boolean} lg - True if viewport width is at least 64rem
   * @property {boolean} xl - True if viewport width is at least 80rem
   * @property {boolean} 2xl - True if viewport width is at least 96rem
   * @throws {Error} If accessed during initialization in test environment
   * @deprecated Using viewport properties during initialization is forbidden
   */
  viewport = Array.from(
    // Values match those in viewport.scss
    Object.entries({
      sm: new TrackedMediaQuery("(min-width: 40rem)"),
      md: new TrackedMediaQuery("(min-width: 48rem)"),
      lg: new TrackedMediaQuery("(min-width: 64rem)"),
      xl: new TrackedMediaQuery("(min-width: 80rem)"),
      "2xl": new TrackedMediaQuery("(min-width: 96rem)"),
    })
  ).reduce((obj, [key, breakpointQuery]) => {
    Object.defineProperty(obj, key, {
      get() {
        siteInitialized ||= getOwnerWithFallback(this).lookup(
          "-application-instance:main"
        )?._booted;

        if (!siteInitialized) {
          if (isTesting() || isRailsTesting()) {
            throw new Error(
              `Accessing \`capabilities.viewport.${key}\` during the site initialization phase. Move these checks ` +
                `to a component, transformer, or API callback that executes during page rendering.`
            );
          }

          deprecated(
            `Accessing \`capabilities.viewport.${key}\` during the site initialization phase is not recommended. ` +
              `Using these values during initialization can lead to errors and inconsistencies when the browser ` +
              `window is resized. Please move these checks to a component, transformer, or API callback that ` +
              `executes during page rendering.`,
            {
              id: "discourse.static-viewport-initialization",
              url: "https://meta.discourse.org/t/367810",
            }
          );
        }

        return breakpointQuery.matches;
      },
    });

    return obj;
  }, {});

  #isMobileDevice =
    Mobile.mobileForced || (ua.includes("Mobile") && !ua.includes("iPad"));

  get isMobileDevice() {
    return this.#isMobileDevice;
  }

  get touch() {
    return anyPointerCourseQuery.matches;
  }

  get userHasBeenActive() {
    return (
      !("userActivation" in navigator) || navigator.userActivation.hasBeenActive
    );
  }

  get supportsServiceWorker() {
    return (
      "serviceWorker" in navigator &&
      typeof ServiceWorkerRegistration !== "undefined" &&
      !this.isAppWebview &&
      navigator.serviceWorker.controller &&
      navigator.serviceWorker.controller.state === "activated"
    );
  }
}

export const capabilities = new Capabilities();

export default class CapabilitiesServiceShim {
  static isServiceFactory = true;

  static create() {
    return capabilities;
  }
}
