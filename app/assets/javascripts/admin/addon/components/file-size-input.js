import Component from "@ember/component";
import { action, computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import I18n from "discourse-i18n";

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

/**
  An input field for a file size.

**/
@classNames("file-size-picker")
export default class FileSizeInput extends Component {
  init() {
    super.init(...arguments);
    let sizeValueKB = this.get("sizeValueKB");
    this.set("sizeValue", sizeValueKB);
    this._defaultUnit(sizeValueKB);
  }

  _defaultUnit(sizeValueKB) {
    this.set("fileSizeUnit", "kb");
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

  keyDown(event) {
    return ALLOWED_KEYS.includes(event.key);
  }

  @computed("dropdownOptions")
  get dropdownOptions() {
    return [
      { label: "kb", value: "kb" },
      { label: "mb", value: "mb" },
      { label: "gb", value: "gb" },
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
        this.set("fileSizeKB", newSize);
        break;
      case "mb":
        this.set("fileSizeKB", newSize * 1024);
        break;
      case "gb":
        this.set("fileSizeKB", newSize * 1024 * 1024);
        break;
    }
    if (this.fileSizeKB > this.max) {
      this.updateValidationMessage(
        I18n.toHumanSize(this.fileSizeKB * 1024) +
          " is greater than the max allowed " +
          I18n.toHumanSize(this.max * 1024)
      );
    } else {
      this.onChangeSize(this.fileSizeKB);
      this.updateValidationMessage(null);
    }
  }

  @action
  onFileSizeUnitChange(newUnit) {
    this.set("unitChanged", true);
    if (this.fileSizeUnit === "kb" && newUnit === "mb") {
      this.fileSize = this.get("sizeValue");
      let calculatedSize = this.fileSize / 1024;
      this.set("sizeValue", calculatedSize);
    }
    if (this.fileSizeUnit === "kb" && newUnit === "gb") {
      this.fileSize = this.get("sizeValue");
      let calculatedSize = this.fileSize / 1024 / 1024;
      this.set("sizeValue", calculatedSize);
    }
    if (this.fileSizeUnit === "mb" && newUnit === "kb") {
      this.fileSize = this.get("sizeValue");
      let calculatedSize = this.fileSize * 1024;
      this.set("sizeValue", calculatedSize);
    }
    if (this.fileSizeUnit === "mb" && newUnit === "gb") {
      this.fileSize = this.get("sizeValue");
      let calculatedSize = this.fileSize / 1024;
      this.set("sizeValue", calculatedSize);
    }
    if (this.fileSizeUnit === "gb" && newUnit === "mb") {
      this.fileSize = this.get("sizeValue");
      let calculatedSize = this.fileSize * 1024;
      this.set("sizeValue", calculatedSize);
    }
    if (this.fileSizeUnit === "gb" && newUnit === "kb") {
      this.fileSize = this.get("sizeValue");
      let calculatedSize = this.fileSize * 1024 * 1024;
      this.set("sizeValue", calculatedSize);
    }
    this.set("fileSizeUnit", newUnit);
  }
}
