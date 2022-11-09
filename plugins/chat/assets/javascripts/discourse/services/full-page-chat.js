import Service, { inject as service } from "@ember/service";
import { defaultHomepage } from "discourse/lib/utilities";

export default class FullPageChat extends Service {
  @service router;

  _previousURL = null;
  _isActive = false;

  enter(previousURL) {
    this._previousURL = previousURL;
    this._isActive = true;
  }

  exit() {
    if (this.isDestroyed || this.isDestroying) {
      return;
    }

    this._isActive = false;

    let previousURL = this._previousURL;
    if (!previousURL || previousURL === "/") {
      previousURL = this.router.urlFor(`discovery.${defaultHomepage()}`);
    }

    this._previousURL = null;

    return previousURL;
  }

  get isActive() {
    return this._isActive;
  }
}
