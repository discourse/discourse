import UserField from "admin/models/user-field";

export default Discourse.Route.extend({
  model: function() {
    return this.store.findAll("user-field");
  },

  setupController: function(controller, model) {
    controller.setProperties({ model, fieldTypes: UserField.fieldTypes() });
  }
});
