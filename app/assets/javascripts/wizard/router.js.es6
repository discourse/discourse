const Router = Ember.Router.extend({
  rootURL: '/wizard',
  location: Ember.testing ? 'none': 'history'
});

Router.map(function() {
  this.route('step', { path: '/steps/:step_id' });
});

export default Router;
