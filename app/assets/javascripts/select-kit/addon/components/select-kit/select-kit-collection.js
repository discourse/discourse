import Component from "@ember/component";
import { notEmpty } from "@ember/object/computed";
import layout from "select-kit/templates/components/select-kit/select-kit-collection";

export default Component.extend({
  layout,
  classNames: ["select-kit-collection"],
  tagName: "ul",
  isVisible: notEmpty("collection")
});
