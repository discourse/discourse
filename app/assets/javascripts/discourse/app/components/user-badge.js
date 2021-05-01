import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  tagName: "",

  @discourseComputed("count")
  showGrantCount(count) {
    return count && count > 1;
  },

  @discourseComputed("badge", "user")
  badgeUrl() {
    // NOTE: I tried using a link-to helper here but the queryParams mean it fails
    let username = this.get("user.username_lower") || "";
    username = username !== "" ? "?username=" + username : "";
    return this.get("badge.url") + username;
  },
});
