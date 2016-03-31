import ColorScheme from 'admin/models/color-scheme';

export default Ember.Route.extend({

  model() {
    return ColorScheme.findAll();
  },

  deactivate() {
    this._super();
    this.controllerFor('adminCustomizeColors').set('selectedItem', null);
  },

});
