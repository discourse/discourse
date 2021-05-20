import Component from "@ember/component";
import { empty } from "@ember/object/computed";
import layout from "select-kit/templates/components/select-kit/select-kit-collection";

export default Component.extend({
  layout,
  classNames: ["select-kit-collection"],
  classNameBindings: ["shouldHide:hidden"],
  tagName: "ul",
  shouldHide: empty("collection"),
});
