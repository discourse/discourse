export default Ember.Route.extend({
  beforeModel: function() {
    this.transitionTo("group.activity.posts");
  }
});
