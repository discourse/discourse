import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { allowOnlyNumericInput } from "discourse/lib/utilities";
import ComboBox from "discourse/select-kit/components/combo-box";
import I18n, { i18n } from "discourse-i18n";

const UNIT_KB = "kb";
const UNIT_MB = "mb";
const UNIT_GB = "gb";
const KB_PER_UNIT = {
  [UNIT_KB]: 1,
  [UNIT_MB]: 1024,
  [UNIT_GB]: 1024 * 1024,
};

export default class FileSizeInput extends Component {
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

    return sizeInKB / KB_PER_UNIT[this.unit];
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

    const sizeInKB = value * KB_PER_UNIT[this.unit];

    this.args.onChangeSize(sizeInKB, this.#validationMessage(sizeInKB));
  }

  @action
  onFileSizeUnitChange(newUnit) {
    this.unit = newUnit;
  }

  #validationMessage(sizeInKB) {
    if (sizeInKB > this.args.max) {
      return i18n("file_size_input.error.size_too_large", {
        provided_file_size: I18n.toHumanSize(sizeInKB * 1024),
        max_file_size: I18n.toHumanSize(this.args.max * 1024),
      });
    }

    if (sizeInKB < this.args.min) {
      return i18n("file_size_input.error.size_too_small", {
        provided_file_size: I18n.toHumanSize(sizeInKB * 1024),
        min_file_size: I18n.toHumanSize(this.args.min * 1024),
      });
    }
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
      <ComboBox
        class="file-size-unit-selector"
        @content={{this.dropdownOptions}}
        @onChange={{this.onFileSizeUnitChange}}
        @value={{this.unit}}
        @valueProperty="value"
      />
    </div>
  </template>
}
