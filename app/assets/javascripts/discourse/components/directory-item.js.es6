import Component from "@ember/component";
import { propertyEqual } from "discourse/lib/computed";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  tagName: "tr",
  classNameBindings: ["me"],
  me: propertyEqual("item.user.id", "currentUser.id"),

  @discourseComputed("item.user")
  user(itemUser) {
    const includesProfile = this.siteSettings.user_directory_includes_profile;
    return includesProfile ? itemUser.user : itemUser;
  }
});
