import {
  default as computed,
  on
} from "ember-addons/ember-computed-decorators";

const userDismissedPromptKey = "dismissed-pwa-install-banner";

export default Ember.Component.extend({
  deferredInstallPromptEvent: null,

  @on("init")
  _registerListener() {
    var that = this;
    window.addEventListener("beforeinstallprompt", e => {
      // Prevent Chrome 76+ from automatically showing the prompt
      e.preventDefault();
      // Stash the event so it can be triggered later
      that.set("deferredInstallPromptEvent", e);
    });
  },

  @computed
  bannerDismissed: {
    set(value) {
      localStorage.setItem(userDismissedPromptKey, value);
      return localStorage.getItem(userDismissedPromptKey);
    },
    get() {
      return localStorage.getItem(userDismissedPromptKey);
    }
  },

  @computed("deferredInstallPromptEvent", "bannerDismissed")
  showPWAInstallBanner() {
    return (
      this.currentUser && // User must be logged in
      this.currentUser.trust_level > 0 && // Be at least trust_level 1
      this.deferredInstallPromptEvent && // Pass the browser engagement checks
      !window.matchMedia("(display-mode: standalone)").matches && // Not be in the installed PWA already
      !this.bannerDismissed // Have not a previously dismissed install banner
    );
  },

  actions: {
    turnon() {
      this.set("bannerDismissed", true);
      this.deferredInstallPromptEvent.prompt();
    },
    dismiss() {
      this.set("bannerDismissed", true);
    }
  }
});
