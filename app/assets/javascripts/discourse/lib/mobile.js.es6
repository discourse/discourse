import deprecated from "discourse-common/lib/deprecated";

let mobileForced = false;

//  An object that is responsible for logic related to mobile devices.
const Mobile = {
  isMobileDevice: false,
  mobileView: false,

  init() {
    const $html = $("html");
    this.isMobileDevice = mobileForced || $html.hasClass("mobile-device");
    this.mobileView = mobileForced || $html.hasClass("mobile-view");

    if (Ember.testing || mobileForced) {
      return;
    }

    try {
      if (window.location.search.match(/mobile_view=1/)) {
        localStorage.mobileView = true;
      }
      if (window.location.search.match(/mobile_view=0/)) {
        localStorage.mobileView = false;
      }
      if (localStorage.mobileView) {
        var savedValue = localStorage.mobileView === "true";
        if (savedValue !== this.mobileView) {
          this.reloadPage(savedValue);
        }
      }
    } catch (err) {
      // localStorage may be disabled, just skip this
      // you get security errors if it is disabled
    }

    // Sam: I tried this to disable zooming on iOS 10 but it is not consistent
    //  you can still sometimes trigger zoom and be stuck in a horrible state
    //
    // let iOS = !!navigator.platform && /iPad|iPhone|iPod/.test(navigator.platform);
    // if (iOS) {
    //   document.documentElement.addEventListener('touchstart', function (event) {
    //     if (event.touches.length > 1) {
    //       event.preventDefault();
    //     }
    //   }, false);
    // }
  },

  toggleMobileView() {
    try {
      if (localStorage) {
        localStorage.mobileView = !this.mobileView;
      }
    } catch (err) {
      // localStorage may be disabled, skip
    }
    this.reloadPage(!this.mobileView);
  },

  reloadPage(mobile) {
    window.location.assign(
      window.location.pathname + "?mobile_view=" + (mobile ? "1" : "0")
    );
  }
};

export function forceMobile() {
  mobileForced = true;
}

export function resetMobile() {
  mobileForced = false;
}

Object.defineProperty(Discourse, "Mobile", {
  get() {
    deprecated(
      "`Discourse.Mobile` is deprecated, use `this.site.mobileView` instead"
    );
    return Mobile;
  }
});

export default Mobile;
