import { set, setProperties } from "@ember/object";
import { extractError } from "discourse/lib/ajax-error";
import { action } from "@ember/object";
import { reads } from "@ember/object/computed";

export default Ember.Controller.extend({
  error: null,

  automation: reads("model.automation"),

  @action
  saveAutomation(automation) {
    this.set("error", null);
    automation.update().catch(e => {
      this.set("error", extractError(e));
    });
  },

  @action
  onChangeField(field, identifier, value) {
    set(field, `metadata.${identifier}`, value);
  },

  @action
  onChangeTrigger(name) {
    set(this.model.automation.trigger, "name", name);
  }
});
