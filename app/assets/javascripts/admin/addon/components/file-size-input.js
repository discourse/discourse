import Component from "@ember/component";
import { action, computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";

/**
  An input field for a file size.

**/
@classNames("file-size-picker")
export default class FileSizeInput extends Component {
  init() {
    super.init(...arguments);
    let sizeValueKB = this.get("sizeValueKB");
    this.set("sizeValue", sizeValueKB);
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
    this.onChangeSize(this.fileSizeKB);
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
