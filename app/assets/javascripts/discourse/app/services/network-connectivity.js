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
      this.handleConnectivityChangeEvent(false);
    });

    window.addEventListener("online", () => {
      this.handleConnectivityChangeEvent(true);
    });
  }

  handleConnectivityChangeEvent(connected) {
    if (connected) {
      // Make a super cheap request to the server. If we get a response, we are connected!
      return ajax("/srv/status", { dataType: "text" })
        .then((response) => {
          this.setConnectivity(response === "ok");
        })
        .catch(() => {
          this.setConnectivity(false);
        });
    } else {
      this.setConnectivity(false);
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
