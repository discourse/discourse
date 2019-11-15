import discourseComputed from "discourse-common/utils/decorators";
import { alias } from "@ember/object/computed";
import Component from "@ember/component";
import { userPath } from "discourse/lib/url";

export function normalize(name) {
  return name.replace(/[\-\_ \.]/g, "").toLowerCase();
}

export default Component.extend({
  classNameBindings: [":user-info", "size"],
  attributeBindings: ["data-username"],
  size: "small",

  @discourseComputed("user.username")
  userPath(username) {
    return userPath(username);
  },

  "data-username": alias("user.username"),

  // TODO: In later ember releases `hasBlock` works without this
  hasBlock: alias("template"),

  @discourseComputed("user.name", "user.username")
  name(name, username) {
    if (name && normalize(username) !== normalize(name)) {
      return name;
    }
  }
});
