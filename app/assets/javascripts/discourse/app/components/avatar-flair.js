import MountWidget from "discourse/components/mount-widget";
import { observes } from "discourse-common/utils/decorators";

export default MountWidget.extend({
  widget: "avatar-flair",

  @observes("flairName", "flairUrl", "flairBgColor", "flairColor")
  _rerender() {
    this.queueRerender();
  },

  buildArgs() {
    return {
      flair_name: this.flairName,
      flair_url: this.flairUrl,
      flair_bg_color: this.flairBgColor,
      flair_color: this.flairColor,
    };
  },
});
