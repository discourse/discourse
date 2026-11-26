import { dependentKeyCompat } from "@ember/object/compat";
import { addUniqueValueToArray } from "discourse/lib/array-tools";
import { deepEqual } from "discourse/lib/object";
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
  get validValues() {
    const originalValidValues = this.settingObj.get("valid_values");
    const values = [];
    const translateNames = this.settingObj.translate_names;

    (originalValidValues || []).forEach((v) => {
      if (v.name && v.name.length > 0 && translateNames) {
        addUniqueValueToArray(values, { name: i18n(v.name), value: v.value });
      } else {
        addUniqueValueToArray(values, v);
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
}
