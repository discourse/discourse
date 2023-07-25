import Service from "@ember/service";
import discourseDebounce from "discourse-common/lib/debounce";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse-common/utils/decorators";
import { cancel } from "@ember/runloop";
import { tracked } from "@glimmer/tracking";

const CONNECTIVITY_ERROR_CLASS = "network-disconnected";

export default class NetworkConnectivity extends Service {
  @tracked connected = true;

  constructor() {
    super(...arguments);

    this.setConnectivity(navigator.onLine);

    window.addEventListener("offline", this.pingServerAndSetConnectivity);
    window.addEventListener("online", this.pingServerAndSetConnectivity);
    window.addEventListener("visibilitychange", this.onFocus);
  }

  @bind
  onFocus() {
    if (!this.connected && document.visibilityState === "visible") {
      this.pingServerAndSetConnectivity();
    }
  }

  @bind
  async pingServerAndSetConnectivity() {
    cancel(this._successTimer);

    if (this._request?.abort) {
      this._request.abort();
    }

    this._requesting = true;

    this._request = ajax("/srv/status", { dataType: "text" }).then(
      (response) => {
        if (response === "ok") {
          this._requesting = false;
          return this.setConnectivity(true);
        }
      }
    );

    this._successTimer = discourseDebounce(
      this,
      this.checkPingStatusAndRerun,
      1000
    );
  }

  @bind
  async checkPingStatusAndRerun() {
    if (this._requesting) {
      this.setConnectivity(false);
      this.pingServerAndSetConnectivity();
    } else {
      this.setConnectivity(true);
    }
  }

  @bind
  setConnectivity(connected) {
    this.connected = connected;

    document.documentElement.classList.toggle(
      CONNECTIVITY_ERROR_CLASS,
      !connected
    );
  }
}
