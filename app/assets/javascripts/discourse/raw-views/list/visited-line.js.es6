import computed from "ember-addons/ember-computed-decorators";

export default Ember.Object.extend({
  @computed
  isLastVisited: function() {
    return this.get("lastVisitedTopic") === this.get("topic");
  }
});
