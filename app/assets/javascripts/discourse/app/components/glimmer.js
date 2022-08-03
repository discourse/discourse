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
  @service siteSettings;
  @service messageBus;
  @service currentUser;
  @service session;
  @service site;

  @cached
  get topicTrackingState() {
    const applicationInstance = getOwner(this);
    return applicationInstance.lookup("topic-tracking-state:main");
  }
}
