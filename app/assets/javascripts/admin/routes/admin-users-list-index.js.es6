export default Discourse.Route.extend({
  beforeModel: function() {
    this.replaceWith('adminUsersList.show', 'active');
  }
});
