import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import autoGroupFlairForUser from "discourse/lib/avatar-flair";
import discourseComputed from "discourse/lib/decorators";

@tagName("")
export default class UserAvatarFlair extends Component {
  @discourseComputed("user")
  flair(user) {
    if (!user || !user.flair_group_id) {
      return;
    }

    if (user.flair_url || user.flair_bg_color) {
      return {
        flairName: user.flair_name,
        flairUrl: user.flair_url,
        flairBgColor: user.flair_bg_color,
        flairColor: user.flair_color,
      };
    }

    const autoFlairAttrs = autoGroupFlairForUser(this.site, user);
    if (autoFlairAttrs) {
      return {
        flairName: autoFlairAttrs.flair_name,
        flairUrl: autoFlairAttrs.flair_url,
        flairBgColor: autoFlairAttrs.flair_bg_color,
        flairColor: autoFlairAttrs.flair_color,
      };
    }
  }
}
