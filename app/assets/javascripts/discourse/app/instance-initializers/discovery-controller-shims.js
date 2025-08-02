import EmberObject from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { service } from "@ember/service";
import deprecated from "discourse/lib/deprecated";

let reopenedClasses = [];

function ControllerShim(resolverName, deprecationId) {
  return class AbstractControllerShim extends EmberObject {
    static printDeprecation() {
      deprecated(
        `${resolverName} no longer exists, and this shim will eventually be removed. To fetch information about the current discovery route, use the discovery service instead.`,
        {
          id: deprecationId,
        }
      );
    }

    static reopen() {
      this.printDeprecation();
      reopenedClasses.push(resolverName);
      return super.reopen(...arguments);
    }

    @service discovery;

    constructor() {
      super(...arguments);
      this.constructor.printDeprecation();
    }
  };
}

class NavigationCategoryControllerShim extends ControllerShim(
  "controller:navigation/category",
  "discourse.navigation-category-controller"
) {
  @dependentKeyCompat
  get category() {
    this.constructor.printDeprecation();
    return this.discovery.category;
  }
}

class DiscoveryTopicsControllerShim extends ControllerShim(
  "controller:discovery/topics",
  "discourse.discovery-topics-controller"
) {
  @dependentKeyCompat
  get model() {
    this.constructor.printDeprecation();
    if (this.discovery.onDiscoveryRoute) {
      return this.discovery.currentTopicList;
    }
  }

  @dependentKeyCompat
  get category() {
    this.constructor.printDeprecation();
    if (this.discovery.onDiscoveryRoute) {
      return this.discovery.category;
    }
  }
}

class TagShowControllerShim extends ControllerShim(
  "controller:tag-show",
  "discourse.tag-show-controller"
) {
  @dependentKeyCompat
  get tag() {
    this.constructor.printDeprecation();
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

    container.lookup("service:router").on("routeDidChange", (transition) => {
      const destination = transition.to?.name;
      if (
        destination?.startsWith("discovery.") ||
        destination?.startsWith("tags.show") ||
        destination === "tag.show"
      ) {
        // Ensure any reopened shims are initialized in case anything has added observers
        reopenedClasses.forEach((resolverName) =>
          container.lookup(resolverName)
        );
      }
    });
  },
};
