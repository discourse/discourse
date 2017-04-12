export default Ember.Route.extend({
  beforeModel() {
    this.transitionTo('adminCustomizeThemes');
  }
});
