import discourseComputed from "discourse-common/utils/decorators";
import { or } from "@ember/object/computed";
import Component from "@ember/component";

export default Component.extend({
  classNames: ["controls"],

  buttonDisabled: or("model.isSaving", "saveDisabled"),

  @discourseComputed("model.isSaving")
  savingText(saving) {
    return saving ? "saving" : "save";
  }
});
