import computed from "ember-addons/ember-computed-decorators";

export default Ember.Mixin.create({
  @computed("value", "default")
  overridden(val, defaultVal) {
    if (val === null) val = "";
    if (defaultVal === null) defaultVal = "";

    return val.toString() !== defaultVal.toString();
  },

  @computed("valid_values")
  validValues(validValues) {
    const vals = [],
      translateNames = this.get("translate_names");

    validValues.forEach(v => {
      if (v.name && v.name.length > 0 && translateNames) {
        vals.addObject({ name: I18n.t(v.name), value: v.value });
      } else {
        vals.addObject(v);
      }
    });
    return vals;
  },

  @computed("valid_values")
  allowsNone(validValues) {
    if (validValues && validValues.indexOf("") >= 0) {
      return "admin.settings.none";
    }
  }
});
