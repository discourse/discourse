import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";
import { computed } from "@ember/object";
import I18n from "I18n";

export default Component.extend({
  tagName: "",
  field: null,
  automation: null,
  tagName: "",

  @discourseComputed("automation.trigger.id", "field.triggerable")
  displayField(triggerId, triggerable) {
    return triggerId && (!triggerable || triggerable === triggerId);
  },

  placeholdersString: computed("field.placeholders", function () {
    return this.field.placeholders.join(", ");
  }),

  target: computed("field.target", function () {
    return this.field.target === "script"
      ? `.scriptables.${this.automation.script.id.replace(/-/g, "_")}.`
      : `.triggerables.${this.automation.trigger.id.replace(/-/g, "_")}.`;
  }),

  description: computed("target", function () {
    return I18n.lookup(
      `discourse_automation${this.target}fields.${this.field.name}.description`,
      { locale: I18n.locale }
    );
  }),
});
