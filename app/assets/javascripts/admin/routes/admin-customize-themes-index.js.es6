export default Ember.Route.extend({
  setupController() {
    this.controllerFor("adminCustomizeThemes").set("editingTheme", false);
  }
});
