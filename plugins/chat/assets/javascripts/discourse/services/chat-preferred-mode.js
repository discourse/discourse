import KeyValueStore from "discourse/lib/key-value-store";
import Service from "@ember/service";
import Site from "discourse/models/site";

const PREFERRED_MODE_KEY = "preferred_mode";
const PREFERRED_MODE_STORE_NAMESPACE = "discourse_chat_";
const FULL_PAGE_CHAT = "FULL_PAGE_CHAT";
const DRAWER_CHAT = "DRAWER_CHAT";

export default class ChatPreferredMode extends Service {
  _store = new KeyValueStore(PREFERRED_MODE_STORE_NAMESPACE);

  setFullPage() {
    this._store.setObject({ key: PREFERRED_MODE_KEY, value: FULL_PAGE_CHAT });
  }

  setDrawer() {
    this._store.setObject({ key: PREFERRED_MODE_KEY, value: DRAWER_CHAT });
  }

  get isFullPage() {
    return !!(
      Site.currentProp("mobileView") ||
      this._store.getObject(PREFERRED_MODE_KEY) === FULL_PAGE_CHAT
    );
  }

  get isDrawer() {
    return !!(
      !Site.currentProp("mobileView") &&
      (!this._store.getObject(PREFERRED_MODE_KEY) ||
        this._store.getObject(PREFERRED_MODE_KEY) === DRAWER_CHAT)
    );
  }
}
