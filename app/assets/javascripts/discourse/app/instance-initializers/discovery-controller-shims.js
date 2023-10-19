import EmberObject from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { inject as service } from "@ember/service";
import deprecated from "discourse-common/lib/deprecated";

class NavigationCategoryControllerShim extends EmberObject {
  @service discovery;

  @dependentKeyCompat
  get category() {
    deprecated(
      "controller:navigation/category no longer exists, and this shim will eventually be removed. Use the discovery service instead.",
      {
        id: "discourse.navigation-category-controller",
      }
    );
    return this.discovery.category;
  }
}

class DiscoveryTopicsControllerShim extends EmberObject {
  @service discovery;

  @dependentKeyCompat
  get model() {
    deprecated(
      "controller:navigation/category no longer exists, and this shim will eventually be removed. Use the discovery service instead.",
      {
        id: "discourse.navigation-category-controller",
      }
    );
    if (this.discovery.onDiscoveryRoute) {
      return this.discovery.currentTopicList;
    }
  }
}

class TagShowControllerShim extends EmberObject {
  @service discovery;

  @dependentKeyCompat
  get tag() {
    deprecated(
      "controller:tag-show no longer exists, and this shim will eventually be removed. Use the discovery service instead.",
      {
        id: "discourse.tag-show-controller",
      }
    );
    return this.discovery.tag;
  }
}

export default {
  initialize(container) {
    container.register(
      "controller:navigation/category",
      NavigationCategoryControllerShim
    );

    container.register(
      "controller:discovery/topics",
      DiscoveryTopicsControllerShim
    );

    container.register("controller:tag-show", TagShowControllerShim);
  },
};
