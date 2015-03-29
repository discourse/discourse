// A base route that allows us to redirect when access is restricted

export default Discourse.Route.extend({

  afterModel() {
    if (!this.modelFor('user').get('can_edit')) {
      this.replaceWith('userActivity');
    }
  }

});
