import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";
import { action } from "@ember/object";
export default class AdminCustomizeFormTemplatesIndex extends DiscourseRoute {
  model() {
    return ajax("/admin/customize/form_templates.json").then((model) => {
      return model.form_templates.sort(
        (a, b) => parseFloat(a.id) - parseFloat(b.id)
      );
    });
  }

  setupController(controller, model) {
    controller.set("model", model);
  }

  @action
  reloadModel() {
    this.refresh();
  }
}
