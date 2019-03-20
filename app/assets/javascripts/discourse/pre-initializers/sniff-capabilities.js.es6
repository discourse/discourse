/*global safari:true*/

// Initializes an object that lets us know about our capabilities.
export default {
  name: "sniff-capabilities",
  initialize(container, application) {
    const $html = $("html"),
      touch = navigator.maxTouchPoints > 1 || "ontouchstart" in window,
      caps = { touch };

    // Store the touch ability in our capabilities object
    $html.addClass(
      touch ? "touch discourse-touch" : "no-touch discourse-no-touch"
    );

    // Detect Devices
    if (navigator) {
      const ua = navigator.userAgent;
      if (ua) {
        caps.isAndroid = ua.indexOf("Android") !== -1;
        caps.isWinphone = ua.indexOf("Windows Phone") !== -1;

        caps.isOpera = !!window.opera || ua.indexOf(" OPR/") >= 0;
        caps.isFirefox = typeof InstallTrigger !== "undefined";
        caps.isSafari =
          Object.prototype.toString
            .call(window.HTMLElement)
            .indexOf("Constructor") > 0 ||
          (function(p) {
            return p.toString() === "[object SafariRemoteNotification]";
          })(!window["safari"] || safari.pushNotification);
        caps.isChrome = !!window.chrome && !caps.isOpera;
        caps.isIE11 = !!ua.match(/Trident.*rv\:11\./);

        caps.canPasteImages = caps.isChrome || caps.isFirefox;
      }

      caps.isIOS =
        /iPad|iPhone|iPod/.test(navigator.userAgent) && !window.MSStream;
    }

    // We consider high res a device with 1280 horizontal pixels. High DPI tablets like
    // iPads should report as 1024.
    caps.highRes = window.screen.width >= 1280;

    // Inject it
    application.register("capabilities:main", caps, { instantiate: false });
    application.inject("view", "capabilities", "capabilities:main");
    application.inject("controller", "capabilities", "capabilities:main");
    application.inject("component", "capabilities", "capabilities:main");
  }
};
