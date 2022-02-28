import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";
import { computed } from "@ember/object";
import I18n from "I18n";

export default class AutomationField extends Component {
  tagName = "";
  field = null;
  automation = null;
  saveAutomation = null;
  tagName = "";

  @discourseComputed("automation.trigger.id", "field.triggerable")
  displayField(triggerId, triggerable) {
    return triggerId && (!triggerable || triggerable === triggerId);
  }

  @computed("field.placeholders")
  get placeholdersString() {
    return this.field.placeholders.join(", ");
  }

  @computed("field.target")
  get target() {
    return this.field.target === "script"
      ? `.scriptables.${this.automation.script.id.replace(/-/g, "_")}.`
      : `.triggerables.${this.automation.trigger.id.replace(/-/g, "_")}.`;
  }

  @computed("target", "field.name")
  get description() {
    return I18n.lookup(
      `discourse_automation${this.target}fields.${this.field.name}.description`,
      { locale: I18n.locale }
    );
  }
}
