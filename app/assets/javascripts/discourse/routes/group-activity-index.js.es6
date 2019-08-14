export default Ember.Route.extend({
  afterModel(model) {
    if (model.can_see_members) {
      this.transitionTo("group.activity.posts");
    } else {
      this.transitionTo("group.activity.mentions");
    }
  }
});
