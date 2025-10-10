import { action } from "@ember/object";
import DiscourseRoute from "discourse/routes/discourse";
import FormTemplate from "admin/models/form-template";

export default class AdminCustomizeFormTemplatesIndex extends DiscourseRoute {
  model() {
    return FormTemplate.findAll();
  }

  @action
  reloadModel() {
    this.refresh();
  }
}
