import GlimmerComponent from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { getOwner } from "@ember/application";
import { inject as service } from "@ember/service";

/*
  Glimmer components are not EmberObjects, and therefore do not support automatic
  injection of the things defined in `pre-initializers/inject-discourse-objects`.

  This base class provides an alternative. All these references are looked up lazily,
  so the performance impact should be negligible
*/

export default class DiscourseGlimmerComponent extends GlimmerComponent {
  @service appEvents;
  @service store;
  @service("search") searchService;
  @service keyValueStore;
  @service pmTopicTrackingState;

  @cached
  get siteSettings() {
    const applicationInstance = getOwner(this);
    return applicationInstance.lookup("site-settings:main");
  }

  @cached
  get currentUser() {
    const applicationInstance = getOwner(this);
    return applicationInstance.lookup("current-user:main");
  }

  @cached
  get messageBus() {
    const applicationInstance = getOwner(this);
    return applicationInstance.lookup("message-bus:main");
  }

  @cached
  get topicTrackingState() {
    const applicationInstance = getOwner(this);
    return applicationInstance.lookup("topic-tracking-state:main");
  }

  @cached
  get site() {
    const applicationInstance = getOwner(this);
    return applicationInstance.lookup("site:main");
  }

  @cached
  get store() {
    const applicationInstance = getOwner(this);
    return applicationInstance.lookup("store:main");
  }

  @cached
  get session() {
    const applicationInstance = getOwner(this);
    return applicationInstance.lookup("session:main");
  }
}
