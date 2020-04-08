import Component from "@ember/component";
import { notEmpty } from "@ember/object/computed";

export default Component.extend({
  layoutName: "select-kit/templates/components/select-kit/errors-collection",
  classNames: ["select-kit-errors-collection"],
  tagName: "ul",
  isVisible: notEmpty("collection.content")
});
