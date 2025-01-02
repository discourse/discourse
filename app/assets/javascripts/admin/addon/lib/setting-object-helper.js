import { computed } from "@ember/object";
import { readOnly } from "@ember/object/computed";
import { isPresent } from "@ember/utils";
import { deepEqual } from "discourse-common/lib/object";
import { i18n } from "discourse-i18n";

export default class SettingObjectHelper {
  @readOnly("settingObj.allow_any") anyValue;

  constructor(settingObj) {
    this.settingObj = settingObj;
  }

  @computed("settingObj.value", "settingObj.default")
  get overridden() {
    let val = this.settingObj.value;
    let defaultVal = this.settingObj.default;

    if (val === null) {
      val = "";
    }
    if (defaultVal === null) {
      defaultVal = "";
    }

    return !deepEqual(val, defaultVal);
  }

  @computed("settingObj.valueProperty", "settingObj.validValues.[]")
  get computedValueProperty() {
    if (isPresent(this.settingObj.valueProperty)) {
      return this.settingObj.valueProperty;
    }

    if (isPresent(this.settingObj.validValues.get("firstObject.value"))) {
      return "value";
    }
    return null;
  }

  @computed("settingObj.nameProperty", "settingObj.validValues.[]")
  get computedNameProperty() {
    if (isPresent(this.settingObj.nameProperty)) {
      return this.settingObj.nameProperty;
    }

    if (isPresent(this.settingObj.validValues.get("firstObject.name"))) {
      return "name";
    }
    return null;
  }

  @computed("settingObj.valid_values")
  get validValues() {
    const validValues = this.settingObj.valid_values;
    const values = [];
    const translateNames = this.settingObj.translate_names;

    (validValues || []).forEach((v) => {
      if (v.name && v.name.length > 0 && translateNames) {
        values.addObject({ name: i18n(v.name), value: v.value });
      } else {
        values.addObject(v);
      }
    });
    return values;
  }

  @computed("settingObj.valid_values")
  get allowsNone() {
    if (this.settingObj.valid_values?.includes("")) {
      return "admin.settings.none";
    }
    return undefined;
  }
}
