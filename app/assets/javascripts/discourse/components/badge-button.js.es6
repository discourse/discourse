import { alias } from "@ember/object/computed";
import Component from "@ember/component";
import computed from "ember-addons/ember-computed-decorators";

export default Component.extend({
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
  "data-badge-name": alias("badge.name")
});
