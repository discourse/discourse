import UserField from 'admin/models/user-field';

export default Ember.Route.extend({
  model: function() {
    return UserField.findAll();
  },

  setupController: function(controller, model) {
    controller.setProperties({
      model: model,
      fieldTypes: UserField.fieldTypes()
    });
  }
});
