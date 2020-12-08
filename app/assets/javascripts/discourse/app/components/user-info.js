import Component from "@ember/component";
import { alias } from "@ember/object/computed";
import discourseComputed from "discourse-common/utils/decorators";
import { userPath } from "discourse/lib/url";

export function normalize(name) {
  return name.replace(/[\-\_ \.]/g, "").toLowerCase();
}

export default Component.extend({
  classNameBindings: [":user-info", "size"],
  attributeBindings: ["data-username"],
  size: "small",
  "data-username": alias("user.username"),

  @discourseComputed("user.username")
  userPath(username) {
    return userPath(username);
  },

  @discourseComputed("user.name", "user.username")
  name(name, username) {
    if (name && normalize(username) !== normalize(name)) {
      return name;
    }
  },
});
