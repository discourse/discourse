import Component from "@ember/component";
import layout from "select-kit/templates/components/tag-drop/more-tags-collection";

export default Component.extend({
  tagName: "",

  layout,

  collection: null,
});
