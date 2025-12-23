/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { fn } from "@ember/helper";
import { computed } from "@ember/object";
import ComboBox from "discourse/select-kit/components/combo-box";
import { i18n } from "discourse-i18n";

export default class RemindAssignsFrequency extends Component {
  @computed(
    "user.custom_fields.remind_assigns_frequency",
    "siteSettings.remind_assigns_frequency"
  )
  get selectedFrequency() {
    if (
      this.availableFrequencies
        .map((freq) => freq.value)
        .includes(this.user?.custom_fields?.remind_assigns_frequency)
    ) {
      return this.user?.custom_fields?.remind_assigns_frequency;
    }

    return this.siteSettings?.remind_assigns_frequency;
  }

  @computed("user.reminders_frequency")
  get availableFrequencies() {
    return this.user?.reminders_frequency?.map((freq) => ({
      name: i18n(freq.name),
      value: freq.value,
      selected: false,
    }));
  }

  <template>
    {{#if this.siteSettings.assign_enabled}}
      <div class="controls controls-dropdown">
        <label>{{i18n
            "discourse_assign.reminders_frequency.description"
          }}</label>
        <ComboBox
          @id="remind-assigns-frequency"
          @valueProperty="value"
          @content={{this.availableFrequencies}}
          @value={{this.selectedFrequency}}
          @onChange={{fn
            (mut this.user.custom_fields.remind_assigns_frequency)
          }}
        />
      </div>
    {{/if}}
  </template>
}
