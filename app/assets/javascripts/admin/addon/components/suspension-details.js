import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "I18n";
import { observes } from "discourse-common/utils/decorators";

const CUSTOM_REASON_KEY = "custom";

export default Component.extend({
  tagName: "",
  selectedReason: CUSTOM_REASON_KEY,
  customReason: "",
  reasonKeys: [
    "not_listening_to_staff",
    "consuming_staff_time",
    "combatative",
    "in_wrong_place",
    "no_constructive_purpose",
    CUSTOM_REASON_KEY,
  ],

  @discourseComputed("reasonKeys")
  reasons(keys) {
    return keys.map((key) => {
      return { id: key, name: I18n.t(`admin.user.suspend_reasons.${key}`) };
    });
  },

  @discourseComputed("selectedReason")
  isCustomReason(selectedReason) {
    return selectedReason === CUSTOM_REASON_KEY;
  },

  @observes("isCustomReason", "customReason", "selectedReason")
  setReason() {
    if (this.isCustomReason) {
      this.set("reason", this.customReason);
    } else {
      this.set(
        "reason",
        I18n.t(`admin.user.suspend_reasons.${this.selectedReason}`)
      );
    }
  },
});
