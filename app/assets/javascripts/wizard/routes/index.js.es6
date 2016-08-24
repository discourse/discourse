export default Ember.Route.extend({
  beforeModel() {
    this.replaceWith('step', 'welcome');
  }
});
