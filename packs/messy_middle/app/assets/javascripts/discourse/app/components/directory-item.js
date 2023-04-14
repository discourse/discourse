import Component from "@ember/component";
import { propertyEqual } from "discourse/lib/computed";

export default Component.extend({
  tagName: "div",
  classNames: ["directory-table__row"],
  classNameBindings: ["me"],
  me: propertyEqual("item.user.id", "currentUser.id"),
  columns: null,
});
