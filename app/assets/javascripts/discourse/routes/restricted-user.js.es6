// A base route that allows us to redirect when access is restricted

export default Discourse.Route.extend({

  afterModel: function() {
    var user = this.modelFor('user');
    if (!user.get('can_edit')) {
      this.replaceWith('userActivity');
    }
  }

});
