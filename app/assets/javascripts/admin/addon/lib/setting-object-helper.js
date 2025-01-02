import { dependentKeyCompat } from "@ember/object/compat";
import { isPresent } from "@ember/utils";
import { deepEqual } from "discourse-common/lib/object";
import { i18n } from "discourse-i18n";

export default class SettingObjectHelper {
  constructor(settingObj) {
    this.settingObj = settingObj;
  }

  @dependentKeyCompat
  get overridden() {
    let val = this.settingObj.get("value");
    let defaultVal = this.settingObj.get("default");

    if (val === null) {
      val = "";
    }
    if (defaultVal === null) {
      defaultVal = "";
    }

    return !deepEqual(val, defaultVal);
  }

  @dependentKeyCompat
  get computedValueProperty() {
    if (isPresent(this.settingObj.get("valueProperty"))) {
      return this.settingObj.get("valueProperty");
    }

    if (isPresent(this.validValues.get("firstObject.value"))) {
      return "value";
    }
    return null;
  }

  @dependentKeyCompat
  get computedNameProperty() {
    if (isPresent(this.settingObj.get("nameProperty"))) {
      return this.settingObj.get("nameProperty");
    }

    if (isPresent(this.validValues.get("firstObject.name"))) {
      return "name";
    }
    return null;
  }

  @dependentKeyCompat
  get validValues() {
    const originalValidValues = this.settingObj.get("valid_values");
    const values = [];
    const translateNames = this.settingObj.translate_names;

    (originalValidValues || []).forEach((v) => {
      if (v.name && v.name.length > 0 && translateNames) {
        values.addObject({ name: i18n(v.name), value: v.value });
      } else {
        values.addObject(v);
      }
    });
    return values;
  }

  @dependentKeyCompat
  get allowsNone() {
    if (this.settingObj.get("valid_values")?.includes("")) {
      return "admin.settings.none";
    }
    return undefined;
  }

  @dependentKeyCompat
  get anyValue() {
    return this.settingObj.get("allow_any");
  }
}
