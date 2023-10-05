const APPLE_NAVIGATOR_PLATFORMS = /iPhone|iPod|iPad|Macintosh|MacIntel/;
const APPLE_USER_AGENT_DATA_PLATFORM = /macOS/;

const ua = navigator.userAgent;

class Capabilities {
  touch = navigator.maxTouchPoints > 1 || "ontouchstart" in window;

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

  get userHasBeenActive() {
    return (
      !("userActivation" in navigator) || navigator.userActivation.hasBeenActive
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
