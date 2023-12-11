import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import I18n from "discourse-i18n";
import TextField from "discourse/components/text-field";
import ComboBox from "select-kit/components/combo-box";

const ALLOWED_KEYS = [
  "Enter",
  "Backspace",
  "Tab",
  "Delete",
  "ArrowLeft",
  "ArrowUp",
  "ArrowRight",
  "ArrowDown",
  "0",
  "1",
  "2",
  "3",
  "4",
  "5",
  "6",
  "7",
  "8",
  "9",
];

export default class FileSizeInput extends Component {
  @tracked fileSizeUnit;
  @tracked sizeValue;

  constructor(owner, args) {
    super(owner, args);
    let sizeValueKB = this.args.sizeValueKB;
    this.originalSizeKB = sizeValueKB;
    this.sizeValue = sizeValueKB;

    this._defaultUnit(sizeValueKB);
  }

  _defaultUnit(sizeValueKB) {
    this.fileSizeUnit = "kb";
    if (sizeValueKB <= 1024) {
      this.onFileSizeUnitChange("kb");
    }
    if (sizeValueKB > 1024 && sizeValueKB <= 1024 * 1024) {
      this.onFileSizeUnitChange("mb");
    }
    if (sizeValueKB > 1024 * 1024) {
      this.onFileSizeUnitChange("gb");
    }
  }

  @action
  keyDown(event) {
    if (!ALLOWED_KEYS.includes(event.key)) {
      event.preventDefault();
    }
  }

  get dropdownOptions() {
    return [
      { label: I18n.t("number.human.storage_units.units.kb"), value: "kb" },
      { label: I18n.t("number.human.storage_units.units.mb"), value: "mb" },
      { label: I18n.t("number.human.storage_units.units.gb"), value: "gb" },
    ];
  }

  @action
  handleFileSizeChange(value) {
    if (value !== "") {
      this._onFileSizeChange(value);
    }
  }

  _onFileSizeChange(newSize) {
    switch (this.fileSizeUnit) {
      case "kb":
        this.fileSizeKB = newSize;
        break;
      case "mb":
        this.fileSizeKB = newSize * 1024;
        break;
      case "gb":
        this.fileSizeKB = newSize * 1024 * 1024;
        break;
    }
    if (this.fileSizeKB > this.args.max) {
      this.args.updateValidationMessage(
        I18n.toHumanSize(this.fileSizeKB * 1024) +
          " " +
          I18n.t("file_size_input.error.size_too_large") +
          " " +
          I18n.toHumanSize(this.args.max * 1024)
      );
      // Removes the green save checkmark button
      this.args.onChangeSize(this.originalSizeKB);
    } else {
      this.args.onChangeSize(this.fileSizeKB);
      this.args.updateValidationMessage(null);
    }
  }

  @action
  onFileSizeUnitChange(newUnit) {
    if (this.fileSizeUnit === "kb" && newUnit === "mb") {
      this.sizeValue = this.sizeValue / 1024;
    }
    if (this.fileSizeUnit === "kb" && newUnit === "gb") {
      this.sizeValue = this.sizeValue / 1024 / 1024;
    }
    if (this.fileSizeUnit === "mb" && newUnit === "kb") {
      this.sizeValue = this.sizeValue * 1024;
    }
    if (this.fileSizeUnit === "mb" && newUnit === "gb") {
      this.sizeValue = this.sizeValue / 1024;
    }
    if (this.fileSizeUnit === "gb" && newUnit === "mb") {
      this.sizeValue = this.sizeValue * 1024;
    }
    if (this.fileSizeUnit === "gb" && newUnit === "kb") {
      this.sizeValue = this.sizeValue * 1024 * 1024;
    }
    this.fileSizeUnit = newUnit;
  }

  <template>
    <div class="file-size-picker">
      <TextField
        @class="file-size-input"
        @value={{this.sizeValue}}
        @onChange={{this.handleFileSizeChange}}
        {{on "keydown" this.keyDown}}
      />
      <ComboBox
        @class="file-size-unit-selector"
        @valueProperty="value"
        @content={{this.dropdownOptions}}
        @value={{this.fileSizeUnit}}
        @onChange={{this.onFileSizeUnitChange}}
      />
    </div>
  </template>
}
