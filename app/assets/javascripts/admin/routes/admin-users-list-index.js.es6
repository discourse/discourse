export default Discourse.Route.extend({
  redirect: function() {
    this.replaceWith('adminUsersList.show', 'active');
  }
});
