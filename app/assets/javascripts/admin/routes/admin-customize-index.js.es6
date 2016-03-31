export default Ember.Route.extend({
  beforeModel() {
    this.transitionTo('adminCustomize.colors');
  }
});
