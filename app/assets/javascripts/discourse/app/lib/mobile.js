import $ from "jquery";
import { isTesting } from "discourse/lib/environment";

let mobileForced = false;

//  An object that is responsible for logic related to mobile devices.
const Mobile = {
  isMobileDevice: false,
  mobileView: false,

  init() {
    const $html = $("html");
    this.isMobileDevice = mobileForced || $html.hasClass("mobile-device");
    this.mobileView = mobileForced || $html.hasClass("mobile-view");

    if (isTesting() || mobileForced) {
      return;
    }

    try {
      if (window.location.search.match(/mobile_view=1/)) {
        localStorage.mobileView = true;
      }
      if (window.location.search.match(/mobile_view=0/)) {
        localStorage.mobileView = false;
      }
      if (window.location.search.match(/mobile_view=auto/)) {
        localStorage.removeItem("mobileView");
      }
      if (localStorage.mobileView) {
        let savedValue = localStorage.mobileView === "true";
        if (savedValue !== this.mobileView) {
          this.reloadPage(savedValue);
        }
      }
    } catch {
      // localStorage may be disabled, just skip this
      // you get security errors if it is disabled
    }
  },

  toggleMobileView() {
    try {
      if (localStorage) {
        localStorage.mobileView = !this.mobileView;
      }
    } catch {
      // localStorage may be disabled, skip
    }
    this.reloadPage(!this.mobileView);
  },

  reloadPage(mobile) {
    window.location.assign(
      window.location.pathname + "?mobile_view=" + (mobile ? "1" : "0")
    );
  },
};

export function forceMobile() {
  mobileForced = true;
}

export function resetMobile() {
  mobileForced = false;
}

export default Mobile;
