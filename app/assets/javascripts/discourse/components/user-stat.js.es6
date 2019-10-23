import Component from "@ember/component";
export default Component.extend({
  classNames: ["user-stat"],
  type: "number",
  isNumber: Ember.computed.equal("type", "number"),
  isDuration: Ember.computed.equal("type", "duration")
});
