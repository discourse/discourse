export default Discourse.Route.extend({
  serialize(model) {
    return { web_hook_id: model.get('id') || 'new' };
  },

  model(params) {
    if (params.web_hook_id === 'new') {
      return this.store.createRecord('web-hook');
    }
    return this.store.find('web-hook', Ember.get(params, 'web_hook_id'));
  },

  setupController(controller, model) {
    if (model.get('isNew') || Ember.isEmpty(model.get('web_hook_event_types'))) {
      model.set('web_hook_event_types', controller.get('defaultEventTypes').map(e => e));
    }
    model.set('category_ids', Ember.isEmpty(model.get('category_ids')) ?
      Em.A() :
      model.get('category_ids').map(c => c));

    controller.setProperties({ model, saved: false });
  },

  renderTemplate() {
    this.render('admin/templates/web-hooks-show', { into: 'admin' });
  }
});
