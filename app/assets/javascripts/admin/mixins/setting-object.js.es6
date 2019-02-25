export default Ember.Mixin.create({
  overridden: function() {
    let val = this.get("value"),
      defaultVal = this.get("default");

    if (val === null) val = "";
    if (defaultVal === null) defaultVal = "";

    return val.toString() !== defaultVal.toString();
  }.property("value", "default"),

  validValues: function() {
    const vals = [],
      translateNames = this.get("translate_names");

    this.get("valid_values").forEach(v => {
      if (v.name && v.name.length > 0 && translateNames) {
        vals.addObject({ name: I18n.t(v.name), value: v.value });
      } else {
        vals.addObject(v);
      }
    });
    return vals;
  }.property("valid_values"),

  allowsNone: function() {
    const validValues = this.get("valid_values");
    if (validValues && validValues.indexOf("") >= 0) {
      return "admin.settings.none";
    }
  }.property("valid_values")
});
