import KeyValueStore from "discourse/lib/key-value-store";
import Service from "@ember/service";

const FULL_PAGE = "fullPage";
const STORE_NAMESPACE_CHAT_WINDOW = "discourse_chat_window_";

export default class FullPageChat extends Service {
  store = new KeyValueStore(STORE_NAMESPACE_CHAT_WINDOW);
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

  get isPreferred() {
    return !!this.store.getObject(FULL_PAGE);
  }

  set isPreferred(value) {
    this.store.setObject({ key: FULL_PAGE, value });
  }
}
