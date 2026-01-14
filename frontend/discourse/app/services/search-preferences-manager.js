import Service from "@ember/service";
import KeyValueStore from "discourse/lib/key-value-store";

export default class SearchPreferencesManager extends Service {
  STORE_NAMESPACE = "discourse_search_preferences_manager_";

  store = new KeyValueStore(this.STORE_NAMESPACE);

  get sortOrder() {
    return this.store.getObject("sortOrder");
  }

  set sortOrder(value) {
    this.store.setObject({ key: "sortOrder", value });
  }
}
