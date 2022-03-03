import discourseComputed, { bind, on } from "discourse-common/utils/decorators";
import Component from "@ember/component";

const USER_DISMISSED_PROMPT_KEY = "dismissed-pwa-install-banner";

export default Component.extend({
  deferredInstallPromptEvent: null,

  @bind
  _onInstallPrompt(event) {
    // Prevent Chrome 76+ from automatically showing the prompt
    event.preventDefault();
    // Stash the event so it can be triggered later
    this.set("deferredInstallPromptEvent", event);
  },

  @on("didInsertElement")
  _registerListener() {
    window.addEventListener("beforeinstallprompt", this._onInstallPrompt);
  },

  @on("willDestroyElement")
  _unregisterListener() {
    window.removeEventListener("beforeinstallprompt", this._onInstallPrompt);
  },

  @discourseComputed
  bannerDismissed: {
    set(value) {
      this.keyValueStore.set({ key: USER_DISMISSED_PROMPT_KEY, value });
      return this.keyValueStore.get(USER_DISMISSED_PROMPT_KEY);
    },
    get() {
      return this.keyValueStore.get(USER_DISMISSED_PROMPT_KEY);
    },
  },

  @discourseComputed("deferredInstallPromptEvent", "bannerDismissed")
  showPWAInstallBanner(deferredInstallPromptEvent, bannerDismissed) {
    return (
      this.capabilities.isAndroid &&
      this.get("currentUser.trust_level") > 0 &&
      deferredInstallPromptEvent && // Pass the browser engagement checks
      !window.matchMedia("(display-mode: standalone)").matches && // Not be in the installed PWA already
      !this.capabilities.isAppWebview && // not launched via official app
      !bannerDismissed // Have not a previously dismissed install banner
    );
  },

  actions: {
    turnOn() {
      this.set("bannerDismissed", true);
      this.deferredInstallPromptEvent.prompt();
    },
    dismiss() {
      this.set("bannerDismissed", true);
    },
  },
});
