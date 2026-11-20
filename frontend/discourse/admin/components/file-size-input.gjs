import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { allowOnlyNumericInput } from "discourse/lib/utilities";
import ComboBox from "discourse/select-kit/components/combo-box";
import DSelect from "discourse/ui-kit/select/d-select";
import I18n, { i18n } from "discourse-i18n";

const UNIT_KB = "kb";
const UNIT_MB = "mb";
const UNIT_GB = "gb";

export default class FileSizeInput extends Component {
  @service siteSettings;

  @tracked unit;

  constructor() {
    super(...arguments);

    const sizeInKB = this.args.sizeValueKB;
    if (sizeInKB >= 1024 * 1024) {
      this.unit = UNIT_GB;
    } else if (sizeInKB >= 1024) {
      this.unit = UNIT_MB;
    } else {
      this.unit = UNIT_KB;
    }
  }

  get number() {
    const sizeInKB = this.args.sizeValueKB;
    if (!sizeInKB) {
      return;
    }
    if (this.unit === UNIT_KB) {
      return sizeInKB;
    }
    if (this.unit === UNIT_MB) {
      return sizeInKB / 1024;
    }
    if (this.unit === UNIT_GB) {
      return sizeInKB / 1024 / 1024;
    }
  }

  get dropdownOptions() {
    return [
      { label: i18n("number.human.storage_units.units.kb"), value: UNIT_KB },
      { label: i18n("number.human.storage_units.units.mb"), value: UNIT_MB },
      { label: i18n("number.human.storage_units.units.gb"), value: UNIT_GB },
    ];
  }

  @action
  keyDown(event) {
    allowOnlyNumericInput(event);
  }

  @action
  handleFileSizeChange(event) {
    const value = parseFloat(event.target.value);

    if (isNaN(value)) {
      this.args.onChangeSize();
      return;
    }

    let sizeInKB;
    switch (this.unit) {
      case "kb":
        sizeInKB = value;
        break;
      case "mb":
        sizeInKB = value * 1024;
        break;
      case "gb":
        sizeInKB = value * 1024 * 1024;
        break;
    }

    this.args.onChangeSize(sizeInKB);

    if (sizeInKB > this.args.max) {
      this.args.setValidationMessage(
        i18n("file_size_input.error.size_too_large", {
          provided_file_size: I18n.toHumanSize(sizeInKB * 1024),
          max_file_size: I18n.toHumanSize(this.args.max * 1024),
        })
      );
    } else if (sizeInKB < this.args.min) {
      this.args.setValidationMessage(
        i18n("file_size_input.error.size_too_small", {
          provided_file_size: I18n.toHumanSize(sizeInKB * 1024),
          min_file_size: I18n.toHumanSize(this.args.min * 1024),
        })
      );
    } else {
      this.args.setValidationMessage(null);
    }
  }

  @action
  onFileSizeUnitChange(newUnit) {
    this.unit = newUnit;
  }

  <template>
    <div class="file-size-picker">
      <input
        class="file-size-input"
        step="any"
        type="number"
        value={{this.number}}
        {{on "input" this.handleFileSizeChange}}
        {{on "keydown" this.keyDown}}
      />
      {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
      {{#if this.siteSettings.enable_new_select_controls}}
        <DSelect
          class="file-size-unit-selector"
          @labelField="label"
          @onChange={{this.onFileSizeUnitChange}}
          @options={{this.dropdownOptions}}
          @texts={{hash ariaLabel=(i18n "file_size_input.unit")}}
          @value={{this.unit}}
          @valueField="value"
          @variant="static"
        />
      {{else}}
        <ComboBox
          class="file-size-unit-selector"
          @content={{this.dropdownOptions}}
          @onChange={{this.onFileSizeUnitChange}}
          @value={{this.unit}}
          @valueProperty="value"
        />
      {{/if}}
    </div>
  </template>
}
