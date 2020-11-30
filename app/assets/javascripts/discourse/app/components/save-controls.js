import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import { or } from "@ember/object/computed";

export default Component.extend({
  classNames: ["controls", "save-button"],

  buttonDisabled: or("model.isSaving", "saveDisabled"),

  didInsertElement() {
    this._super(...arguments);
    this.set("saved", false);
  },

  @discourseComputed("model.isSaving")
  savingText(saving) {
    return saving ? "saving" : "save";
  },
});
