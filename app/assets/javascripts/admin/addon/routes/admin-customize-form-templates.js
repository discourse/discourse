import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";

export default class AdminCustomizeFormTemplates extends DiscourseRoute {
  model() {
    return ajax("/admin/customize/form_templates.json").then((model) => {
      return model.form_templates;
    });
  }

  setupController(controller, model) {
    controller.set("model", model);
  }
}
