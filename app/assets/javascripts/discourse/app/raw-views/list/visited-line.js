import EmberObject from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";

export default EmberObject.extend({
  @discourseComputed
  isLastVisited() {
    return this.lastVisitedTopic === this.topic;
  },
});
