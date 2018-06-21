export default Ember.Component.extend({
  classNames: ["user-stat"],
  type: "number",
  isNumber: Ember.computed.equal("type", "number"),
  isDuration: Ember.computed.equal("type", "duration")
});
