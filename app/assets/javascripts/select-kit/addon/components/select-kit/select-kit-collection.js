import Component from "@ember/component";
import { notEmpty } from "@ember/object/computed";

export default Component.extend({
  layoutName:
    "select-kit/templates/components/select-kit/select-kit-collection",
  classNames: ["select-kit-collection"],
  tagName: "ul",
  isVisible: notEmpty("collection")
});
