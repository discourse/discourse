import Component from "@ember/component";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

export default class RemindAssignsFrequency extends Component {
  @discourseComputed(
    "user.custom_fields.remind_assigns_frequency",
    "siteSettings.remind_assigns_frequency"
  )
  selectedFrequency(userAssignsFrequency, siteDefaultAssignsFrequency) {
    if (
      this.availableFrequencies
        .map((freq) => freq.value)
        .includes(userAssignsFrequency)
    ) {
      return userAssignsFrequency;
    }

    return siteDefaultAssignsFrequency;
  }

  @discourseComputed("user.reminders_frequency")
  availableFrequencies(userRemindersFrequency) {
    return userRemindersFrequency.map((freq) => ({
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
          {{! template-lint-disable no-action }}
          @onChange={{action
            (mut this.user.custom_fields.remind_assigns_frequency)
          }}
        />
      </div>
    {{/if}}
  </template>
}
