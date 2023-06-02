import Service from "@ember/service";

export default class AppState extends Service {
  constructor() {
    super(...arguments);

    window.addEventListener("AppStateChange", (event) => {
      // Possible states: "active", "inactive", and "background"
      this._state = event.detail?.newAppState;
    });
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
