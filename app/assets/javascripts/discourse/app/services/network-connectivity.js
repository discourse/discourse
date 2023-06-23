import Service from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { tracked } from "@glimmer/tracking";

const CONNECTIVITY_ERROR_CLASS = "network-disconnected";

export default class NetworkConnectivity extends Service {
  @tracked connected = true;

  constructor() {
    super(...arguments);

    this.setConnectivity(navigator.onLine);

    window.addEventListener("offline", () => {
      this.setConnectivity(false);
    });

    window.addEventListener(
      "online",
      this.pingServerAndSetConnectivity.bind(this)
    );

    window.addEventListener("visibilitychange", this.onFocus.bind(this));
  }

  onFocus() {
    if (!this.connected && document.visibilityState === "visible") {
      this.pingServerAndSetConnectivity();
    }
  }

  async pingServerAndSetConnectivity() {
    let response = await ajax("/srv/status", { dataType: "text" }).catch(() => {
      this.setConnectivity(false);
    });

    this.setConnectivity(response === "ok");
  }

  setConnectivity(connected) {
    this.connected = connected;

    document.documentElement.classList.toggle(
      CONNECTIVITY_ERROR_CLASS,
      !connected
    );
  }
}
