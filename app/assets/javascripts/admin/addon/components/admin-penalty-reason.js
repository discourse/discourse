import Component from "@ember/component";
import { action } from "@ember/object";
import { equal } from "@ember/object/computed";
import { tagName } from "@ember-decorators/component";
import discourseComputed from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";

const CUSTOM_REASON_KEY = "custom";

@tagName("")
export default class AdminPenaltyReason extends Component {
  selectedReason = CUSTOM_REASON_KEY;
  customReason = "";

  reasonKeys = [
    "not_listening_to_staff",
    "consuming_staff_time",
    "combative",
    "in_wrong_place",
    "no_constructive_purpose",
    CUSTOM_REASON_KEY,
  ];

  @equal("selectedReason", CUSTOM_REASON_KEY) isCustomReason;

  @discourseComputed("reasonKeys")
  reasons(keys) {
    return keys.map((key) => {
      return { id: key, name: i18n(`admin.user.suspend_reasons.${key}`) };
    });
  }

  @action
  setSelectedReason(value) {
    this.set("selectedReason", value);
    this.setReason();
  }

  @action
  setCustomReason(value) {
    this.set("customReason", value);
    this.setReason();
  }

  setReason() {
    if (this.isCustomReason) {
      this.set("reason", this.customReason);
    } else {
      this.set(
        "reason",
        i18n(`admin.user.suspend_reasons.${this.selectedReason}`)
      );
    }
  }
}
