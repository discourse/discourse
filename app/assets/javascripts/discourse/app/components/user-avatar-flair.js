import Component from "@ember/component";
import autoGroupFlairForUser from "discourse/lib/avatar-flair";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  tagName: "",

  @discourseComputed("user")
  flair(user) {
    return this.primaryGroupFlair(user) || this.automaticGroupFlair(user);
  },

  primaryGroupFlair(user) {
    if (user.primary_group_flair_url || user.primary_group_flair_bg_color) {
      return {
        flairURL: user.primary_group_flair_url,
        flairBgColor: user.primary_group_flair_bg_color,
        flairColor: user.primary_group_flair_color,
        groupName: user.primary_group_name,
      };
    }
  },

  automaticGroupFlair(user) {
    const autoFlairAttrs = autoGroupFlairForUser(this.site, user);
    if (autoFlairAttrs) {
      return {
        flairURL: autoFlairAttrs.primary_group_flair_url,
        flairBgColor: autoFlairAttrs.primary_group_flair_bg_color,
        flairColor: autoFlairAttrs.primary_group_flair_color,
        groupName: autoFlairAttrs.primary_group_name,
      };
    }
  },
});
