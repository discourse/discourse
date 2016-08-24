const Router = Ember.Router.extend();

Router.map(function () {
  this.route('step', { path: '/step/:step_id' });
});

export default Router;
