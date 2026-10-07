import Helper from "@ember/component/helper";
import { service } from "@ember/service";
import dEmoji from "discourse/ui-kit/helpers/d-emoji";
import dIcon from "discourse/ui-kit/helpers/d-icon";

export default class DiscourseReactionsEmoji extends Helper {
  @service siteSettings;

  compute([reaction], options) {
    // Without emoji rendering, reactions degrade to likes, so every reaction
    // falls back to the configured like icon.
    if (!this.siteSettings.enable_emoji) {
      const icon = this.siteSettings.discourse_reactions_like_icon;
      return dIcon(icon === "heart" ? "d-liked" : icon, {
        ...options,
        "aria-label": reaction,
      });
    }

    return dEmoji(reaction, options);
  }
}
