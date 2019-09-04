export default Ember.Route.extend({
  beforeModel() {
    const group = this.modelFor("group");
    if (group.can_see_members) {
      this.transitionTo("group.activity.posts");
    } else {
      this.transitionTo("group.activity.mentions");
    }
  }
});
