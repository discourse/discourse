import MountWidget from "discourse/components/mount-widget";
import { observes } from "discourse-common/utils/decorators";
import autoGroupFlairForUser from "discourse/lib/avatar-flair";

export default MountWidget.extend({
  widget: "avatar-flair",

  @observes("user")
  _rerender() {
    this.queueRerender();
  },

  buildArgs() {
    if (!this.user) {
      return;
    }

    if (
      this.user.primary_group_flair_url ||
      this.user.primary_group_flair_bg_color
    ) {
      return {
        primary_group_flair_url: this.user.primary_group_flair_url,
        primary_group_flair_bg_color: this.user.primary_group_flair_bg_color,
        primary_group_flair_color: this.user.primary_group_flair_color,
        primary_group_name: this.user.primary_group_name,
      };
    } else {
      const autoFlairAttrs = autoGroupFlairForUser(this.site, this.user);
      if (autoFlairAttrs) {
        return {
          primary_group_flair_url: autoFlairAttrs.primary_group_flair_url,
          primary_group_flair_bg_color:
            autoFlairAttrs.primary_group_flair_bg_color,
          primary_group_flair_color: autoFlairAttrs.primary_group_flair_color,
          primary_group_name: autoFlairAttrs.primary_group_name,
        };
      }
    }
  },
});
