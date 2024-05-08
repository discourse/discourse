import Controller from "@ember/controller";
import EmberObject, { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { extractError } from "discourse/lib/ajax-error";

export default class AutomationNew extends Controller {
  @service router;

  form = null;
  error = null;

  init() {
    super.init(...arguments);
    this._resetForm();
  }

  @action
  saveAutomation() {
    this.set("error", null);

    this.model.automation
      .save(this.form.getProperties("name", "script"))
      .then(() => {
        this._resetForm();
        this.router.transitionTo(
          "adminPlugins.discourse-automation.edit",
          this.model.automation.id
        );
      })
      .catch((e) => {
        this.set("error", extractError(e));
      });
  }

  _resetForm() {
    this.set("form", EmberObject.create({ name: null, script: null }));
  }
}
