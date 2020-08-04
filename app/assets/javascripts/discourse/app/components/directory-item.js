import Component from "@ember/component";
import { propertyEqual } from "discourse/lib/computed";

export default Component.extend({
  tagName: "tr",
  classNameBindings: ["me"],
  me: propertyEqual("item.user.id", "currentUser.id")
});
