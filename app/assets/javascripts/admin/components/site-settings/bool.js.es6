import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  @computed("value")
  enabled: {
    get(value) {
      if (Ember.isEmpty(value)) {
        return false;
      }
      return value.toString() === "true";
    },
    set(value) {
      this.set("value", value ? "true" : "false");
      return value;
    }
  }
});
