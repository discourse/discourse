import Component from "@ember/component";
import { reads } from "@ember/object/computed";

export default Component.extend({
  tagName: "h3",
  layoutName:
    "select-kit/templates/components/toolbar-popup-menu-options/toolbar-popup-menu-options-heading",
  classNames: ["toolbar-popup-menu-options-heading"],
  heading: reads("collection.content.title")
});
