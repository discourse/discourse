import Component from "@ember/component";
import { alias } from "@ember/object/computed";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  tagName: "span",
  classNameBindings: [
    ":user-badge",
    "badge.badgeTypeClassName",
    "badge.enabled::disabled",
  ],

  @discourseComputed("badge.description")
  title(badgeDescription) {
    return $("<div>" + badgeDescription + "</div>").text();
  },

  attributeBindings: ["data-badge-name", "title"],
  "data-badge-name": alias("badge.name"),
});
