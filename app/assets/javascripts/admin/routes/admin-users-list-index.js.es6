export default Discourse.Route.extend({
  beforeModel: function() {
    this.transitionTo('adminUsersList.show', 'active');
  }
});
