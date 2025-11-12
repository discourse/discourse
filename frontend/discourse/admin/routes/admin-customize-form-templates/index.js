import { action } from "@ember/object";
import FormTemplate from "discourse/admin/models/form-template";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminCustomizeFormTemplatesIndex extends DiscourseRoute {
  model() {
    return FormTemplate.findAll();
  }

  @action
  reloadModel() {
    this.refresh();
  }
}
