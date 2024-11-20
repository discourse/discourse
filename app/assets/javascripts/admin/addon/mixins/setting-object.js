import { computed } from "@ember/object";
import { readOnly } from "@ember/object/computed";
import Mixin from "@ember/object/mixin";
import { isPresent } from "@ember/utils";
import { deepEqual } from "discourse-common/lib/object";
import { i18n } from "discourse-i18n";

export default Mixin.create({
  overridden: computed("value", "default", function () {
    let val = this.value;
    let defaultVal = this.default;

    if (val === null) {
      val = "";
    }
    if (defaultVal === null) {
      defaultVal = "";
    }

    return !deepEqual(val, defaultVal);
  }),

  computedValueProperty: computed(
    "valueProperty",
    "validValues.[]",
    function () {
      if (isPresent(this.valueProperty)) {
        return this.valueProperty;
      }

      if (isPresent(this.validValues.get("firstObject.value"))) {
        return "value";
      } else {
        return null;
      }
    }
  ),

  computedNameProperty: computed("nameProperty", "validValues.[]", function () {
    if (isPresent(this.nameProperty)) {
      return this.nameProperty;
    }

    if (isPresent(this.validValues.get("firstObject.name"))) {
      return "name";
    } else {
      return null;
    }
  }),

  validValues: computed("valid_values", function () {
    const validValues = this.valid_values;

    const values = [];
    const translateNames = this.translate_names;

    (validValues || []).forEach((v) => {
      if (v.name && v.name.length > 0 && translateNames) {
        values.addObject({ name: i18n(v.name), value: v.value });
      } else {
        values.addObject(v);
      }
    });
    return values;
  }),

  allowsNone: computed("valid_values", function () {
    if (this.valid_values?.includes("")) {
      return "admin.settings.none";
    }
  }),

  anyValue: readOnly("allow_any"),
});
