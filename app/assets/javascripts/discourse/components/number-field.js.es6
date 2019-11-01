import computed from "ember-addons/ember-computed-decorators";

export default Ember.TextField.extend({
  classNameBindings: ["invalid"],

  @computed("number")
  value: {
    get(number) {
      return parseInt(number, 10);
    },
    set(value) {
      const num = parseInt(value, 10);
      if (isNaN(num)) {
        this.set("invalid", true);
        return value;
      } else {
        this.set("invalid", false);
        this.set("number", num);
        return num.toString();
      }
    }
  },

  @computed("placeholderKey")
  placeholder(key) {
    return key ? I18n.t(key) : "";
  }
});
