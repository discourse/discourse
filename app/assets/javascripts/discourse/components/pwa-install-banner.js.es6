import { bind } from "@ember/runloop";
import Component from "@ember/component";
import {
  default as computed,
  on
} from "ember-addons/ember-computed-decorators";

const USER_DISMISSED_PROMPT_KEY = "dismissed-pwa-install-banner";

export default Component.extend({
  deferredInstallPromptEvent: null,

  _handleInstallPromptEvent(event) {
    // Prevent Chrome 76+ from automatically showing the prompt
    event.preventDefault();
    // Stash the event so it can be triggered later
    this.set("deferredInstallPromptEvent", event);
  },

  @on("didInsertElement")
  _registerListener() {
    this._promptEventHandler = bind(
      this,
      this._handleInstallPromptEvent
    );
    window.addEventListener("beforeinstallprompt", this._promptEventHandler);
  },

  @on("willDestroyElement")
  _unregisterListener() {
    window.removeEventListener("beforeinstallprompt", this._promptEventHandler);
  },

  @computed
  bannerDismissed: {
    set(value) {
      this.keyValueStore.set({ key: USER_DISMISSED_PROMPT_KEY, value });
      return this.keyValueStore.get(USER_DISMISSED_PROMPT_KEY);
    },
    get() {
      return this.keyValueStore.get(USER_DISMISSED_PROMPT_KEY);
    }
  },

  @computed("deferredInstallPromptEvent", "bannerDismissed")
  showPWAInstallBanner() {
    const launchedFromDiscourseHub =
      window.location.search.indexOf("discourse_app=1") !== -1;

    return (
      this.capabilities.isAndroid &&
      this.get("currentUser.trust_level") > 0 &&
      this.deferredInstallPromptEvent && // Pass the browser engagement checks
      !window.matchMedia("(display-mode: standalone)").matches && // Not be in the installed PWA already
      !launchedFromDiscourseHub && // not launched via official app
      !this.bannerDismissed // Have not a previously dismissed install banner
    );
  },

  actions: {
    turnOn() {
      this.set("bannerDismissed", true);
      this.deferredInstallPromptEvent.prompt();
    },
    dismiss() {
      this.set("bannerDismissed", true);
    }
  }
});
