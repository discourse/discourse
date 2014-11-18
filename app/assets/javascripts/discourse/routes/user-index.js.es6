export default Discourse.Route.extend({

  beforeModel: function() {
    this.controllerFor('user').set('indexStream', true);
    return this.replaceWith('userActivity');
  }

});
