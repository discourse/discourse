import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import KeyValueStore from "discourse/lib/key-value-store";

export default class AdminSidebarStateManager extends Service {
  @tracked keywords = new TrackedObject();
  STORE_NAMESPACE = "discourse_admin_sidebar_experiment_";

  store = new KeyValueStore(this.STORE_NAMESPACE);

  get navConfig() {
    return this.store.getObject("navConfig");
  }

  set navConfig(value) {
    this.store.setObject({ key: "navConfig", value });
  }
}
