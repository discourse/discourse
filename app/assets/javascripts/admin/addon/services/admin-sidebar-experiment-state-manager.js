import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import KeyValueStore from "discourse/lib/key-value-store";

export default class AdminSidebarExperimentStateManager extends Service {
  @tracked keywords = {};
  STORE_NAMESPACE = "discourse_admin_sidebar_experiment_";

  store = new KeyValueStore(this.STORE_NAMESPACE);

  get navConfig() {
    return this.store.getObject("navConfig");
  }

  set navConfig(value) {
    this.store.setObject({ key: "navConfig", value });
  }
}
