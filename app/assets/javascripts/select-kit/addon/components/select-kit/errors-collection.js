import Component from "@ember/component";
import { empty } from "@ember/object/computed";
import layout from "select-kit/templates/components/select-kit/errors-collection";

export default Component.extend({
  layout,
  classNames: ["select-kit-errors-collection"],
  classNameBindings: ["shouldHide:hidden"],
  tagName: "ul",
  shouldHide: empty("collection.content"),
});
