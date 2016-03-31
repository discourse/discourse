import Group from 'discourse/models/group';

export default Ember.Route.extend({
  model() {
    return Group.findAll().then(groups => {
      return groups.filter(g => !g.get('automatic'));
    });
  },

  setupController(controller, groups) {
    controller.setProperties({ groups, groupId: null, users: null });
  }
});
