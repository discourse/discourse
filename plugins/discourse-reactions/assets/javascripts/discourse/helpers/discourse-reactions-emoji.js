import Helper from "@ember/component/helper";
import { service } from "@ember/service";
import dEmoji from "discourse/ui-kit/helpers/d-emoji";
import dIcon from "discourse/ui-kit/helpers/d-icon";

export default class DiscourseReactionsEmoji extends Helper {
  @service siteSettings;

  compute([reaction], options) {
    // The like reaction must stay usable without emoji rendering, so fall
    // back to the configured like icon when emojis are disabled site-wide.
    if (
      !this.siteSettings.enable_emoji &&
      reaction === this.siteSettings.discourse_reactions_reaction_for_like
    ) {
      const icon = this.siteSettings.discourse_reactions_like_icon;
      return dIcon(icon === "heart" ? "d-liked" : icon, {
        ...options,
        "aria-label": reaction,
      });
    }

    return dEmoji(reaction, options);
  }
}
