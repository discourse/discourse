import Component from "@ember/component";
import computed from "ember-addons/ember-computed-decorators";

export default Component.extend({
  tagName: "span",

  @computed("count")
  showGrantCount(count) {
    return count && count > 1;
  },

  @computed("badge", "user")
  badgeUrl() {
    // NOTE: I tried using a link-to helper here but the queryParams mean it fails
    var username = this.get("user.username_lower") || "";
    username = username !== "" ? "?username=" + username : "";
    return this.get("badge.url") + username;
  }
});
