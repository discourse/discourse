export default Ember.Object.extend({
  isLastVisited: function() {
    return this.get("lastVisitedTopic") === this.get("topic");
  }.property()
});
