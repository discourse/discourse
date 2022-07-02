import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  tagName: "",

  @discourseComputed("user.role")
  roleName(role) {
    return this.roles.findBy("id", role).label;
  },
});
