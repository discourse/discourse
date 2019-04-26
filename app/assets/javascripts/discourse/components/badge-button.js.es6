import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  tagName: "span",
  classNameBindings: [
    ":user-badge",
    "badge.badgeTypeClassName",
    "badge.enabled::disabled"
  ],

  @computed("badge.description")
  title(badgeDescription) {
    return $("<div>" + badgeDescription + "</div>").text();
  },

  attributeBindings: ["data-badge-name", "title"],
  "data-badge-name": Ember.computed.alias("badge.name")
});
