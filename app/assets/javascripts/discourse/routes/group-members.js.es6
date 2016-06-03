export default Discourse.Route.extend({
  beforeModel: function() {
    this.transitionTo("group.index");
  }
});
