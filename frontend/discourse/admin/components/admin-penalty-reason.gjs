import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import withEventValue from "discourse/helpers/with-event-value";
import ComboBox from "discourse/select-kit/components/combo-box";
import DTextField from "discourse/ui-kit/d-text-field";
import { i18n } from "discourse-i18n";

const CUSTOM_REASON_KEY = "custom";

const REASON_KEYS = [
  "not_listening_to_staff",
  "consuming_staff_time",
  "combative",
  "in_wrong_place",
  "no_constructive_purpose",
  CUSTOM_REASON_KEY,
];

export default class AdminPenaltyReason extends Component {
  @tracked selectedReason = CUSTOM_REASON_KEY;
  @tracked customReason = "";

  reasons = REASON_KEYS.map((key) => ({
    id: key,
    name: i18n(`admin.user.suspend_reasons.${key}`),
  }));

  get isCustomReason() {
    return this.selectedReason === CUSTOM_REASON_KEY;
  }

  @action
  setSelectedReason(value) {
    this.selectedReason = value;
    this.#updateReason();
  }

  @action
  setCustomReason(value) {
    this.customReason = value;
    this.#updateReason();
  }

  #updateReason() {
    this.args.onChangeReason(
      this.isCustomReason
        ? this.customReason
        : i18n(`admin.user.suspend_reasons.${this.selectedReason}`)
    );
  }

  <template>
    <div class="penalty-reason-controls">
      {{#if (eq @penaltyType "suspend")}}
        <label class="suspend-reason-title">{{i18n
            "admin.user.suspend_reason_title"
          }}</label>
        <ComboBox
          class="suspend-reason"
          @content={{this.reasons}}
          @onChange={{this.setSelectedReason}}
          @value={{this.selectedReason}}
        />

        {{#if this.isCustomReason}}
          <DTextField
            class="suspend-reason"
            @onChangeImmediate={{this.setCustomReason}}
            @value={{this.customReason}}
          />
        {{/if}}
      {{else if (eq @penaltyType "silence")}}
        <label class="silence-reason-title">
          {{trustHTML (i18n "admin.user.silence_reason_label")}}</label>

        <ComboBox
          class="silence-reason"
          @content={{this.reasons}}
          @onChange={{this.setSelectedReason}}
          @value={{this.selectedReason}}
        />

        {{#if this.isCustomReason}}
          <DTextField
            class="silence-reason"
            @onChangeImmediate={{this.setCustomReason}}
            @placeholderKey="admin.user.silence_reason_placeholder"
            @value={{this.customReason}}
          />
        {{/if}}
      {{/if}}
    </div>

    <div class="penalty-message-controls">
      <label>{{i18n "admin.user.suspend_message"}}</label>
      <textarea
        class="suspend-message"
        placeholder={{i18n "admin.user.suspend_message_placeholder"}}
        value={{@message}}
        {{on "input" (withEventValue @onChangeMessage)}}
      />
    </div>
  </template>
}
