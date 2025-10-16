import DiscourseRoute from "discourse/routes/discourse";
import FormTemplate from "admin/models/form-template";

export default class AdminCustomizeFormTemplatesEdit extends DiscourseRoute {
  model(params) {
    return FormTemplate.findById(params.id);
  }
}
