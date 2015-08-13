export default Ember.Route.extend({

  model() {
    return Discourse.ColorScheme.findAll();
  },

  deactivate() {
    this._super();
    this.controllerFor('adminCustomizeColors').set('selectedItem', null);
  },

});
