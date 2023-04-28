import Service from "@ember/service";
import { tracked } from "@glimmer/tracking";

const CONNECTIVITY_ERROR_CLASS = "message-bus-offline";

export default class MessageBusConnectivity extends Service {
  @tracked connected = true;

  setConnectivity(connected) {
    this.connected = connected;
    document.documentElement.classList.toggle(
      CONNECTIVITY_ERROR_CLASS,
      !connected
    );
  }
}
