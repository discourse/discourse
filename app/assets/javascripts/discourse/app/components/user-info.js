import Component from "@ember/component";
import { alias } from "@ember/object/computed";
import discourseComputed from "discourse-common/utils/decorators";
import { userPath } from "discourse/lib/url";
import { prioritizeNameInUx } from "discourse/lib/settings";

export default Component.extend({
  classNameBindings: [":user-info", "size"],
  attributeBindings: ["data-username"],
  size: "small",
  "data-username": alias("user.username"),
  includeLink: true,
  includeAvatar: true,

  @discourseComputed("user.username")
  userPath(username) {
    return userPath(username);
  },

  @discourseComputed("user.name")
  nameFirst(name) {
    return prioritizeNameInUx(name);
  },
});
