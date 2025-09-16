import deprecated from "discourse/lib/deprecated";
import { isTesting } from "discourse/lib/environment";
import { getOwnerWithFallback } from "discourse/lib/get-owner";

let mobileForced = false;

//  An object that is responsible for logic related to mobile devices.
const Mobile = {
  mobileView: false,

  init() {
    const documentClassList = document.documentElement.classList;
    this.mobileView = mobileForced || documentClassList.contains("mobile-view");

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
    } catch {
      // localStorage may be disabled, just skip this
      // you get security errors if it is disabled
    }
  },

  get mobileForced() {
    return mobileForced;
  },

  get isMobileDevice() {
    deprecated(
      "`Mobile.isMobileDevice` is deprecated. Use `capabilities.isMobileDevice` instead.",
      { id: "discourse.site.is-mobile-device", since: "3.5.0.beta9-dev" }
    );

    return getOwnerWithFallback(this).lookup("service:capabilities")
      .isMobileDevice;
  },

  maybeReload() {
    if (localStorage.mobileView) {
      let savedValue = localStorage.mobileView === "true";
      if (savedValue !== this.mobileView) {
        this.reloadPage(savedValue);
      }
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
  Mobile.init();
}

export function resetMobile() {
  mobileForced = false;
  Mobile.init();
}

Mobile.init();

export default Mobile;
