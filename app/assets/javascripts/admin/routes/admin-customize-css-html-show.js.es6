export default Ember.Route.extend({
  model(params) {
    const all = this.modelFor('adminCustomizeCssHtml');
    const model = all.findProperty('id', parseInt(params.site_customization_id));
    return model ? { model, section: params.section } : this.replaceWith('adminCustomizeCssHtml.index');
  },

  setupController(controller, hash) {
    controller.setProperties(hash);
  }
});
