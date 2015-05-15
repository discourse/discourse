export default Discourse.Route.extend({
  beforeModel: function() {
    this.replaceWith(this.controllerFor('application').get('loginRequired') ? 'login' : 'discovery').then(function(e) {
      Ember.run.next(function() {
        e.send('showForgotPassword');
      });
    });
  },

  model: function() {
    return Discourse.StaticPage.find('password-reset');
  },

  renderTemplate: function() {
    // do nothing
    this.render('static');
  },

  setupController: function(controller, model) {
    this.controllerFor('static').set('model', model);
  }
});
