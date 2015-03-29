export default Discourse.Route.extend({
  redirect: function() {
    this.replaceWith('adminFlags.list', 'active');
  }
});
