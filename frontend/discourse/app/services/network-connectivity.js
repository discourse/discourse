import { tracked } from "@glimmer/tracking";
import { cancel } from "@ember/runloop";
import Service from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import discourseDebounce from "discourse/lib/debounce";
import { bind } from "discourse/lib/decorators";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";

const CONNECTIVITY_ERROR_CLASS = "network-disconnected";

@disableImplicitInjections
export default class NetworkConnectivity extends Service {
  @tracked connected = true;

  constructor() {
    super(...arguments);

    window.addEventListener("offline", () => {
      this.setConnectivity(false);
      this.startTimerToCheckNavigator();
    });

    window.addEventListener("online", this.pingServerAndSetConnectivity);

    window.addEventListener("visibilitychange", this.onFocus);

    if (!navigator.onLine) {
      this.pingServerAndSetConnectivity();
    }
  }

  @bind
  onFocus() {
    if (!this.connected && document.visibilityState === "visible") {
      this.pingServerAndSetConnectivity();
    }
  }

  @bind
  async pingServerAndSetConnectivity() {
    try {
      let response = await ajax("/srv/status", { dataType: "text" });
      if (response === "ok") {
        cancel(this._timer);
        this.setConnectivity(true);
      } else {
        throw "disconnected";
      }
    } catch {
      // Either the request didn't go out at all or the response wasn't "ok". Both are failures.
      // Start the timer to check every second if `navigator.onLine` comes back online in the event that
      // we miss the `online` event firing
      this.startTimerToCheckNavigator();
    }
  }

  @bind
  startTimerToCheckNavigator() {
    cancel(this._timer);

    this._timer = discourseDebounce(this, this.checkNavigatorOnline, 1000);
  }

  @bind
  checkNavigatorOnline() {
    if (navigator.onLine) {
      this.pingServerAndSetConnectivity();
    } else {
      this.startTimerToCheckNavigator();
    }
  }

  setConnectivity(connected) {
    this.connected = connected;

    document.documentElement.classList.toggle(
      CONNECTIVITY_ERROR_CLASS,
      !connected
    );
  }
}
