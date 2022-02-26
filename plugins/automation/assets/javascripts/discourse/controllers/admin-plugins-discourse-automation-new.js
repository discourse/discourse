import { extractError } from "discourse/lib/ajax-error";
import EmberObject, { action } from "@ember/object";

export default Ember.Controller.extend({
  form: null,
  error: null,

  init() {
    this._super(...arguments);

    this._resetForm();
  },

  @action
  saveAutomation(automation) {
    this.set("error", null);

    automation
      .save(this.form.getProperties("name", "script"))
      .then(() => {
        this._resetForm();
        this.transitionToRoute(
          "adminPlugins.discourse-automation.edit",
          automation.id
        );
      })
      .catch((e) => {
        this.set("error", extractError(e));
      });
  },

  _resetForm() {
    this.set("form", EmberObject.create({ name: null, script: null }));
  },
});
