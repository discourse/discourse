import { observes } from "@ember-decorators/object";
import MountWidget from "discourse/components/mount-widget";

// TODO (glimmer-post-stream): this component needs to be converted to Glimmer
export default class AvatarFlair extends MountWidget {
  widget = "avatar-flair";

  @observes("flairName", "flairUrl", "flairBgColor", "flairColor")
  _rerender() {
    this.queueRerender();
  }

  buildArgs() {
    return {
      flair_name: this.flairName,
      flair_url: this.flairUrl,
      flair_bg_color: this.flairBgColor,
      flair_color: this.flairColor,
    };
  }
}
