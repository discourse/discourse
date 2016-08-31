const Router = Ember.Router.extend({
  location: Ember.testing ? 'none': 'hash'
});

Router.map(function () {
  this.route('step', { path: '/step/:step_id' });
});

export default Router;
