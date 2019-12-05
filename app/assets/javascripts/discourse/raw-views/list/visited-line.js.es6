import discourseComputed from "discourse-common/utils/decorators";
import EmberObject from "@ember/object";

export default EmberObject.extend({
  @discourseComputed
  isLastVisited: function() {
    return this.lastVisitedTopic === this.topic;
  }
});
