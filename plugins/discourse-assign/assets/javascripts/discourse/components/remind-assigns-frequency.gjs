import Component from "@glimmer/component";
import { action, get, set } from "@ember/object";
import { service } from "@ember/service";
import ComboBox from "discourse/select-kit/components/combo-box";
import { i18n } from "discourse-i18n";

export default class RemindAssignsFrequency extends Component {
  @service siteSettings;

  get selectedFrequency() {
    const user = this.args.user;
    const frequency =
      user && get(user, "custom_fields.remind_assigns_frequency");

    if (
      this.availableFrequencies.map((freq) => freq.value).includes(frequency)
    ) {
      return frequency;
    }

    return this.siteSettings.remind_assigns_frequency;
  }

  get availableFrequencies() {
    return this.args.user?.reminders_frequency?.map((freq) => ({
      name: i18n(freq.name),
      value: freq.value,
      selected: false,
    }));
  }

  @action
  onChange(frequency) {
    set(this.args.user, "custom_fields.remind_assigns_frequency", frequency);
  }

  <template>
    <div ...attributes>
      {{#if this.siteSettings.assign_enabled}}
        <div class="controls controls-dropdown">
          <label>{{i18n
              "discourse_assign.reminders_frequency.description"
            }}</label>
          <ComboBox
            @content={{this.availableFrequencies}}
            @id="remind-assigns-frequency"
            @onChange={{this.onChange}}
            @value={{this.selectedFrequency}}
            @valueProperty="value"
          />
        </div>
      {{/if}}
    </div>
  </template>
}
