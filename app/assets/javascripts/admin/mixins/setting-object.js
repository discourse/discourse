import I18n from "I18n";
import discourseComputed from "discourse-common/utils/decorators";
import { computed } from "@ember/object";
import Mixin from "@ember/object/mixin";
import { isPresent } from "@ember/utils";

export default Mixin.create({
  @discourseComputed("value", "default")
  overridden(val, defaultVal) {
    if (val === null) val = "";
    if (defaultVal === null) defaultVal = "";

    return val.toString() !== defaultVal.toString();
  },

  computedValueProperty: computed(
    "valueProperty",
    "validValues.[]",
    function() {
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

  computedNameProperty: computed("nameProperty", "validValues.[]", function() {
    if (isPresent(this.nameProperty)) {
      return this.nameProperty;
    }

    if (isPresent(this.validValues.get("firstObject.name"))) {
      return "name";
    } else {
      return null;
    }
  }),

  @discourseComputed("valid_values")
  validValues(validValues) {
    const vals = [],
      translateNames = this.translate_names;

    validValues.forEach(v => {
      if (v.name && v.name.length > 0 && translateNames) {
        vals.addObject({ name: I18n.t(v.name), value: v.value });
      } else {
        vals.addObject(v);
      }
    });
    return vals;
  },

  @discourseComputed("valid_values")
  allowsNone(validValues) {
    if (validValues && validValues.indexOf("") >= 0) {
      return "admin.settings.none";
    }
  }
});
