import Service from "@ember/service";

export default class FullPageChat extends Service {
  _previousURL = null;
  _isActive = false;

  enter(previousURL) {
    this._previousURL = previousURL;
    this._isActive = true;
  }

  exit() {
    this._isActive = false;
    return this._previousURL;
  }

  get isActive() {
    return this._isActive;
  }
}
