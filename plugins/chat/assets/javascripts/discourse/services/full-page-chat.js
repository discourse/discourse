import Service from "@ember/service";

export default class FullPageChat extends Service {
  _previousRouteInfo = null;
  _isActive = false;

  enter(previousRouteInfo) {
    this._previousRouteInfo = previousRouteInfo;
    this._isActive = true;
  }

  exit() {
    this._isActive = false;
    return this._previousRouteInfo;
  }

  get isActive() {
    return this._isActive;
  }
}
