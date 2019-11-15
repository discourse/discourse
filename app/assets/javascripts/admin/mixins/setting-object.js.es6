import discourseComputed from "discourse-common/utils/decorators";
import Mixin from "@ember/object/mixin";

export default Mixin.create({
  @discourseComputed("value", "default")
  overridden(val, defaultVal) {
    if (val === null) val = "";
    if (defaultVal === null) defaultVal = "";

    return val.toString() !== defaultVal.toString();
  },

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
