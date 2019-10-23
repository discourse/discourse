import Component from "@ember/component";
export default Component.extend({
  tagName: "a",
  attributeBindings: ["href", "data-user-card"],
  href: Ember.computed.alias("user.path"),
  "data-user-card": Ember.computed.alias("user.username")
});
