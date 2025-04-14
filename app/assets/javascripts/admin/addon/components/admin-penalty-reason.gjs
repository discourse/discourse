import Component, { Textarea } from "@ember/component";
import { action } from "@ember/object";
import { equal } from "@ember/object/computed";
import { tagName } from "@ember-decorators/component";
import { eq } from "truth-helpers";
import TextField from "discourse/components/text-field";
import htmlSafe from "discourse/helpers/html-safe";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

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

  <template>
    <div class="penalty-reason-controls">
      {{#if (eq @penaltyType "suspend")}}
        <label class="suspend-reason-title">{{i18n
            "admin.user.suspend_reason_title"
          }}</label>
        <ComboBox
          @content={{this.reasons}}
          @value={{this.selectedReason}}
          @onChange={{this.setSelectedReason}}
          class="suspend-reason"
        />

        {{#if this.isCustomReason}}
          <TextField
            @value={{this.customReason}}
            @onChange={{this.setCustomReason}}
            class="suspend-reason"
          />
        {{/if}}
      {{else if (eq @penaltyType "silence")}}
        <label class="silence-reason-title">
          {{htmlSafe (i18n "admin.user.silence_reason_label")}}</label>

        <ComboBox
          @content={{this.reasons}}
          @value={{this.selectedReason}}
          @onChange={{this.setSelectedReason}}
          class="silence-reason"
        />

        {{#if this.isCustomReason}}
          <TextField
            @value={{this.customReason}}
            @onChange={{this.setCustomReason}}
            @placeholderKey="admin.user.silence_reason_placeholder"
            class="silence-reason"
          />
        {{/if}}
      {{/if}}
    </div>

    <div class="penalty-message-controls">
      <label>{{i18n "admin.user.suspend_message"}}</label>
      <Textarea
        @value={{this.message}}
        class="suspend-message"
        placeholder={{i18n "admin.user.suspend_message_placeholder"}}
      />
    </div>
  </template>
}
