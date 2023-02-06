import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";

export default class AdminCustomizeFormTemplatesEdit extends DiscourseRoute {
  model(params) {
    return ajax(`/admin/customize/form-templates/${params.id}.json`).then(
      (model) => {
        return model.form_template;
      }
    );
  }

  setupController(controller, model) {
    controller.set("model", model);
  }
}
