import EmberObject from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { inject as service } from "@ember/service";
import deprecated from "discourse-common/lib/deprecated";

function printDeprecation(name, id) {
  deprecated(
    `${name} no longer exists, and this shim will eventually be removed. Use the discovery service instead.`,
    {
      id,
    }
  );
}

class NavigationCategoryControllerShim extends EmberObject {
  static reopen() {
    printDeprecation(
      "controller:navigation/category",
      "discourse.navigation-category-controller"
    );
  }

  @service discovery;

  @dependentKeyCompat
  get category() {
    printDeprecation(
      "controller:navigation/category",
      "discourse.navigation-category-controller"
    );
    return this.discovery.category;
  }
}

class DiscoveryTopicsControllerShim extends EmberObject {
  static reopen() {
    printDeprecation(
      "controller:discovery/topics",
      "discourse.discovery-topics-controller"
    );
  }

  @service discovery;

  @dependentKeyCompat
  get model() {
    printDeprecation(
      "controller:discovery/topics",
      "discourse.discovery-topics-controller"
    );
    if (this.discovery.onDiscoveryRoute) {
      return this.discovery.currentTopicList;
    }
  }
}

class TagShowControllerShim extends EmberObject {
  static reopen() {
    printDeprecation("controller:tag-show", "discourse.tag-show-controller");
  }

  @service discovery;

  @dependentKeyCompat
  get tag() {
    printDeprecation("controller:tag-show", "discourse.tag-show-controller");
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
