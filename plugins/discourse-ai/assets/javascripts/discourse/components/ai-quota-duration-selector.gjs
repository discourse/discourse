import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

const DURATION_PRESETS = [
  {
    id: "3600",
    seconds: 3600,
    nameKey: "discourse_ai.llms.quotas.durations.hour",
  },
  {
    id: "21600",
    seconds: 21600,
    nameKey: "discourse_ai.llms.quotas.durations.six_hours",
  },
  {
    id: "86400",
    seconds: 86400,
    nameKey: "discourse_ai.llms.quotas.durations.day",
  },
  {
    id: "604800",
    seconds: 604800,
    nameKey: "discourse_ai.llms.quotas.durations.week",
  },
  { id: "custom", nameKey: "discourse_ai.llms.quotas.durations.custom" },
];

export default class DurationSelector extends Component {
  @tracked selectedPresetId = "86400"; // Default to 1 day
  @tracked customHours = null;

  constructor() {
    super(...arguments);
    const seconds = this.args.value;
    const preset = DURATION_PRESETS.find((p) => p.seconds === seconds);
    if (preset) {
      this.selectedPresetId = preset.id;
    } else {
      this.selectedPresetId = "custom";
      this.customHours = Math.round(seconds / 3600);
    }
  }

  get presetOptions() {
    return DURATION_PRESETS.map((preset) => ({
      id: preset.id,
      name: i18n(preset.nameKey),
      seconds: preset.seconds,
    }));
  }

  get isCustom() {
    return this.selectedPresetId === "custom";
  }

  get currentDurationSeconds() {
    if (this.isCustom) {
      return this.customHours ? this.customHours * 3600 : 0;
    } else {
      return parseInt(this.selectedPresetId, 10);
    }
  }

  @action
  onPresetChange(value) {
    this.selectedPresetId = value;
    this.updateValue();
  }

  @action
  onCustomHoursChange(event) {
    this.customHours = parseInt(event.target.value, 10);
    this.updateValue();
  }

  updateValue() {
    if (this.args.onChange) {
      this.args.onChange(this.currentDurationSeconds);
    }
  }

  <template>
    <div class="duration-selector">
      <ComboBox
        @content={{this.presetOptions}}
        @value={{this.selectedPresetId}}
        @onChange={{this.onPresetChange}}
        class="duration-selector__preset"
      />

      {{#if this.isCustom}}
        <div class="duration-selector__custom">
          <input
            type="number"
            value={{this.customHours}}
            class="duration-selector__hours-input"
            min="1"
            {{on "input" this.onCustomHoursChange}}
          />
          <span class="duration-selector__hours-label">
            {{i18n "discourse_ai.llms.quotas.hours"}}
          </span>
        </div>
      {{/if}}
    </div>
  </template>
}
