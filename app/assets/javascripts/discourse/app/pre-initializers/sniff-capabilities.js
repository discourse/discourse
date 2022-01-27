// Initializes an object that lets us know about browser's capabilities

const APPLE_NAVIGATOR_PLATFORMS = /iPhone|iPod|iPad|Macintosh|MacIntel/;

const APPLE_USERAGENTDATA_PLATFORM = /macOS/;

export default {
  name: "sniff-capabilities",

  initialize(_, app) {
    const html = document.querySelector("html");
    const touch = navigator.maxTouchPoints > 1 || "ontouchstart" in window;
    const ua = navigator.userAgent;
    const caps = { touch };

    if (touch) {
      html.classList.add("touch", "discourse-touch");
    } else {
      html.classList.add("no-touch", "discourse-no-touch");
    }

    caps.isAndroid = ua.includes("Android");
    caps.isWinphone = ua.includes("Windows Phone");
    caps.isOpera = !!window.opera || ua.includes(" OPR/");
    caps.isFirefox = typeof InstallTrigger !== "undefined";
    caps.isChrome = !!window.chrome && !caps.isOpera;
    caps.isSafari =
      /Constructor/.test(window.HTMLElement) ||
      window.safari?.pushNotification.toString() ===
        "[object SafariRemoteNotification]";
    caps.isIpadOS = ua.includes("Mac OS") && !/iPhone|iPod/.test(ua) && touch;
    caps.isIOS =
      (/iPhone|iPod/.test(navigator.userAgent) || caps.isIpadOS) &&
      !window.MSStream;

    caps.isApple =
      APPLE_NAVIGATOR_PLATFORMS.test(navigator.platform) ||
      (navigator.userAgentData &&
        APPLE_USERAGENTDATA_PLATFORM.test(navigator.userAgentData.platform));

    caps.hasContactPicker =
      "contacts" in navigator && "ContactsManager" in window;
    caps.canVibrate = "vibrate" in navigator;
    caps.isPwa =
      window.matchMedia("(display-mode: standalone)").matches ||
      window.navigator.standalone ||
      document.referrer.includes("android-app://");

    // Inject it
    app.register("capabilities:main", caps, { instantiate: false });
    app.inject("view", "capabilities", "capabilities:main");
    app.inject("controller", "capabilities", "capabilities:main");
    app.inject("component", "capabilities", "capabilities:main");
  },
};
