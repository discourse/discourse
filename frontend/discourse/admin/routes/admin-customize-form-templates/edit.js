import FormTemplate from "discourse/admin/models/form-template";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminCustomizeFormTemplatesEdit extends DiscourseRoute {
  model(params) {
    return FormTemplate.findById(params.id);
  }
}
