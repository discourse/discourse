import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  @computed("secondFactorMethod")
  type(secondFactorMethod) {
    if (secondFactorMethod === 1) return "tel";
    if (secondFactorMethod === 2) return "text";
  },

  @computed("secondFactorMethod")
  pattern(secondFactorMethod) {
    if (secondFactorMethod === 1) return "[0-9]{6}";
    if (secondFactorMethod === 2) return "[a-z0-9]{16}";
  },

  @computed("secondFactorMethod")
  maxlength(secondFactorMethod) {
    if (secondFactorMethod === 1) return "6";
    if (secondFactorMethod === 2) return "16";
  }
});
