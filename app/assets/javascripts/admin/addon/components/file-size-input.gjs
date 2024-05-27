import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import TextField from "discourse/components/text-field";
import { allowOnlyNumericInput } from "discourse/lib/utilities";
import I18n from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

const UNIT_KB = "kb";
const UNIT_MB = "mb";
const UNIT_GB = "gb";

export default class FileSizeInput extends Component {
  @tracked fileSizeUnit;
  @tracked sizeValue;
  @tracked pendingSizeValue;
  @tracked pendingFileSizeUnit;

  constructor(owner, args) {
    super(owner, args);
    this.originalSizeKB = this.args.sizeValueKB;
    this.sizeValue = this.args.sizeValueKB;

    this._defaultUnit();
  }

  _defaultUnit() {
    this.fileSizeUnit = UNIT_KB;
    if (this.originalSizeKB <= 1024) {
      this.onFileSizeUnitChange(UNIT_KB);
    } else if (
      this.originalSizeKB > 1024 &&
      this.originalSizeKB <= 1024 * 1024
    ) {
      this.onFileSizeUnitChange(UNIT_MB);
    } else if (this.originalSizeKB > 1024 * 1024) {
      this.onFileSizeUnitChange(UNIT_GB);
    }
  }

  @action
  keyDown(event) {
    allowOnlyNumericInput(event);
  }

  get dropdownOptions() {
    return [
      { label: I18n.t("number.human.storage_units.units.kb"), value: UNIT_KB },
      { label: I18n.t("number.human.storage_units.units.mb"), value: UNIT_MB },
      { label: I18n.t("number.human.storage_units.units.gb"), value: UNIT_GB },
    ];
  }

  @action
  handleFileSizeChange(value) {
    if (value !== "") {
      this.pendingSizeValue = value;
      this._onFileSizeChange(value);
    }
  }

  _onFileSizeChange(newSize) {
    let fileSizeKB;
    switch (this.fileSizeUnit) {
      case "kb":
        fileSizeKB = newSize;
        break;
      case "mb":
        fileSizeKB = newSize * 1024;
        break;
      case "gb":
        fileSizeKB = newSize * 1024 * 1024;
        break;
    }
    if (fileSizeKB > this.args.max) {
      this.args.updateValidationMessage(
        I18n.t("file_size_input.error.size_too_large", {
          provided_file_size: I18n.toHumanSize(fileSizeKB * 1024),
          max_file_size: I18n.toHumanSize(this.args.max * 1024),
        })
      );
      // Removes the green save checkmark button
      this.args.onChangeSize(this.originalSizeKB);
    } else {
      this.args.onChangeSize(fileSizeKB);
      this.args.updateValidationMessage(null);
    }
  }

  @action
  onFileSizeUnitChange(newUnit) {
    if (this.fileSizeUnit === "kb" && newUnit === "kb") {
      this.pendingSizeValue = this.sizeValue;
    }
    if (this.fileSizeUnit === "kb" && newUnit === "mb") {
      this.pendingSizeValue = this.sizeValue / 1024;
    }
    if (this.fileSizeUnit === "kb" && newUnit === "gb") {
      this.pendingSizeValue = this.sizeValue / 1024 / 1024;
    }
    if (this.fileSizeUnit === "mb" && newUnit === "kb") {
      this.pendingSizeValue = this.sizeValue * 1024;
    }
    if (this.fileSizeUnit === "mb" && newUnit === "gb") {
      this.pendingSizeValue = this.sizeValue / 1024;
    }
    if (this.fileSizeUnit === "gb" && newUnit === "mb") {
      this.pendingSizeValue = this.sizeValue * 1024;
    }
    if (this.fileSizeUnit === "gb" && newUnit === "kb") {
      this.pendingSizeValue = this.sizeValue * 1024 * 1024;
    }
    this.pendingFileSizeUnit = newUnit;
  }

  @action
  applySizeValueChanges() {
    this.sizeValue = this.pendingSizeValue;
  }

  @action
  applyUnitChanges() {
    this.fileSizeUnit = this.pendingFileSizeUnit;
  }

  <template>
    <div class="file-size-picker">
      <TextField
        class="file-size-input"
        @value={{this.sizeValue}}
        @onChange={{this.handleFileSizeChange}}
        {{on "keydown" this.keyDown}}
        {{didInsert this.applySizeValueChanges}}
        {{didUpdate this.applySizeValueChanges this.pendingSizeValue}}
      />
      <ComboBox
        class="file-size-unit-selector"
        @valueProperty="value"
        @content={{this.dropdownOptions}}
        @value={{this.fileSizeUnit}}
        @onChange={{this.onFileSizeUnitChange}}
        {{didInsert this.applyUnitChanges}}
        {{didUpdate this.applyUnitChanges this.pendingFileSizeUnit}}
      />
    </div>
  </template>
}
