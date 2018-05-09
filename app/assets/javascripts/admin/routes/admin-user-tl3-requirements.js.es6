export default Discourse.Route.extend({
  model: function() {
    return this.modelFor('adminUser');
  }
});
