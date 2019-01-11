export default Ember.Component.extend({
  tagName: "span",
  classNameBindings: [
    ":user-badge",
    "badge.badgeTypeClassName",
    "badge.enabled::disabled"
  ],
  title: function() {
    return $("<div>" + this.get("badge.description") + "</div>").text();
  }.property("badge.description"),
  attributeBindings: ["data-badge-name", "title"],
  "data-badge-name": Ember.computed.alias("badge.name")
});
