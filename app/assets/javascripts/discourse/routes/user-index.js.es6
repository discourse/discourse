export default Em.Route.extend({
  redirect: function() {
    this.replaceWith('userActivity', this.modelFor('user'));
  }
});
