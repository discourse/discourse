export default Ember.Route.extend({

  model(params) {
    const all = this.modelFor('adminCustomize.colors');
    const model = all.findBy('id', parseInt(params.scheme_id));
    return model ?  model : this.replaceWith('adminCustomize.colors.index');
  },

  serialize(model) {
    return {scheme_id: model.get('id')};
  },

  setupController(controller, model) {
    controller.set('model', model);
    controller.set('allColors', this.modelFor('adminCustomize.colors'));
  }
});

