export default Ember.Route.extend({
  beforeModel() {
    this.replaceWith('adminCustomize.colors');
  }
});
