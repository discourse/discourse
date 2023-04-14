import Component from "@ember/component";
import { alias } from "@ember/object/computed";
export default Component.extend({
  tagName: "a",
  attributeBindings: ["href", "data-user-card"],
  href: alias("user.path"),
  "data-user-card": alias("user.username"),
});
