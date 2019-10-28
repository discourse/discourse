import EmberObject from "@ember/object";
import computed from "ember-addons/ember-computed-decorators";

export default EmberObject.extend({
  @computed
  isLastVisited: function() {
    return this.lastVisitedTopic === this.topic;
  }
});
