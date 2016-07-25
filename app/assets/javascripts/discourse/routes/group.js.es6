import Group from 'discourse/models/group';

export default Discourse.Route.extend({

  titleToken() {
    return [ this.modelFor('group').get('name') ];
  },

  model(params) {
    return Group.find(params.name);
  },

  serialize(model) {
    return { name: model.get('name').toLowerCase() };
  },

  afterModel(model) {
    return Group.findGroupCounts(model.get('name')).then(counts => {
      this.set('counts', counts);
    });
  },

  setupController(controller, model) {
    controller.setProperties({ model, counts: this.get('counts') });
  }
});
