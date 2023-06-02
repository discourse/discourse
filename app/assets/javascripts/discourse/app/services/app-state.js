import Service, { inject as service } from "@ember/service";

export default class AppState extends Service {
  @service capabilities;

  constructor() {
    super(...arguments);

    if (this.capabilities.isAppWebview) {
      window.addEventListener("AppStateChange", (event) => {
        // Possible states: "active", "inactive", and "background"
        this._state = event.detail?.newAppState;
      });
    }
  }

  get active() {
    return this._state === "active";
  }

  get inactive() {
    return this._state === "inactive";
  }

  get background() {
    return this._state === "background";
  }
}
