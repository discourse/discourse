import Component from "@ember/component";
import { action } from "@ember/object";
import { equal } from "@ember/object/computed";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "I18n";

const CUSTOM_REASON_KEY = "custom";

export default Component.extend({
  tagName: "",
  selectedReason: CUSTOM_REASON_KEY,
  customReason: "",
  reasonKeys: [
    "not_listening_to_staff",
    "consuming_staff_time",
    "combative",
    "in_wrong_place",
    "no_constructive_purpose",
    CUSTOM_REASON_KEY,
  ],
  isCustomReason: equal("selectedReason", CUSTOM_REASON_KEY),

  @discourseComputed("reasonKeys")
  reasons(keys) {
    return keys.map((key) => {
      return { id: key, name: I18n.t(`admin.user.suspend_reasons.${key}`) };
    });
  },

  @action
  setSelectedReason(value) {
    this.set("selectedReason", value);
    this.setReason();
  },

  @action
  setCustomReason(value) {
    this.set("customReason", value);
    this.setReason();
  },

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
