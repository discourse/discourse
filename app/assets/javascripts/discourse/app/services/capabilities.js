const APPLE_NAVIGATOR_PLATFORMS = /iPhone|iPod|iPad|Macintosh|MacIntel/;
const APPLE_USER_AGENT_DATA_PLATFORM = /macOS/;

function calculateCapabilities() {
  const capabilities = {};

  const ua = navigator.userAgent;

  capabilities.touch = navigator.maxTouchPoints > 1 || "ontouchstart" in window;

  capabilities.isAndroid = ua.includes("Android");
  capabilities.isWinphone = ua.includes("Windows Phone");
  capabilities.isIpadOS =
    ua.includes("Mac OS") && !/iPhone|iPod/.test(ua) && capabilities.touch;
  capabilities.isIOS =
    (/iPhone|iPod/.test(navigator.userAgent) || capabilities.isIpadOS) &&
    !window.MSStream;
  capabilities.isApple =
    APPLE_NAVIGATOR_PLATFORMS.test(navigator.platform) ||
    (navigator.userAgentData &&
      APPLE_USER_AGENT_DATA_PLATFORM.test(navigator.userAgentData.platform));

  capabilities.isOpera = !!window.opera || ua.includes(" OPR/");
  capabilities.isFirefox = ua.includes("Firefox");
  capabilities.isChrome = !!window.chrome && !capabilities.isOpera;
  capabilities.isSafari =
    /Constructor/.test(window.HTMLElement) ||
    window.safari?.pushNotification?.toString() ===
      "[object SafariRemoteNotification]";

  capabilities.hasContactPicker =
    "contacts" in navigator && "ContactsManager" in window;
  capabilities.canVibrate = "vibrate" in navigator;
  capabilities.isPwa =
    window.matchMedia("(display-mode: standalone)").matches ||
    window.navigator.standalone ||
    document.referrer.includes("android-app://");
  capabilities.isiOSPWA = capabilities.isPwa && capabilities.isIOS;
  capabilities.wasLaunchedFromDiscourseHub =
    window.location.search.includes("discourse_app=1");
  capabilities.isAppWebview = window.ReactNativeWebView !== undefined;

  return capabilities;
}

export const capabilities = calculateCapabilities();

export default class CapabilitiesService {
  static isServiceFactory = true;

  static create() {
    return capabilities;
  }
}
