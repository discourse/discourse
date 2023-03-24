import DiscourseRoute from "discourse/routes/discourse";
import UserField from "admin/models/user-field";

export default class AdminUserFieldsRoute extends DiscourseRoute {
  model() {
    return this.store.findAll("user-field");
  }

  setupController(controller, model) {
    controller.setProperties({ model, fieldTypes: UserField.fieldTypes() });
  }
}
