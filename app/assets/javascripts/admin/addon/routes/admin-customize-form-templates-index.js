import { action } from "@ember/object";
import DiscourseRoute from "discourse/routes/discourse";
import FormTemplate from "admin/models/form-template";

export default class AdminCustomizeFormTemplatesIndex extends DiscourseRoute {
  model() {
    return FormTemplate.findAll();
  }

  setupController(controller, model) {
    controller.set("model", model);
  }

  @action
  reloadModel() {
    this.refresh();
  }
}
