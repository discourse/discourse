import TrackedMediaQuery from "discourse/lib/tracked-media-query";

const APPLE_NAVIGATOR_PLATFORMS = /iPhone|iPod|iPad|Macintosh|MacIntel/;
const APPLE_USER_AGENT_DATA_PLATFORM = /macOS/;

const ua = navigator.userAgent;

// Values match those in viewport.scss
const breakpointQueries = {
  sm: new TrackedMediaQuery("(min-width: 40rem)"),
  md: new TrackedMediaQuery("(min-width: 48rem)"),
  lg: new TrackedMediaQuery("(min-width: 64rem)"),
  xl: new TrackedMediaQuery("(min-width: 80rem)"),
  "2xl": new TrackedMediaQuery("(min-width: 96rem)"),
};

const anyPointerCourseQuery = new TrackedMediaQuery("(any-pointer: coarse)");

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
  isSafari =
    /Constructor/.test(window.HTMLElement) ||
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

  viewport = {
    get sm() {
      return breakpointQueries.sm.matches;
    },
    get md() {
      return breakpointQueries.md.matches;
    },
    get lg() {
      return breakpointQueries.lg.matches;
    },
    get xl() {
      return breakpointQueries.xl.matches;
    },
    get "2xl"() {
      return breakpointQueries["2xl"].matches;
    },
  };

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
