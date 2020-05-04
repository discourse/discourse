import { observes } from "discourse-common/utils/decorators";
import MountWidget from "discourse/components/mount-widget";

export default MountWidget.extend({
  widget: "avatar-flair",

  @observes("flairURL", "flairBgColor", "flairColor")
  _rerender() {
    this.queueRerender();
  },

  buildArgs() {
    return {
      primary_group_flair_url: this.flairURL,
      primary_group_flair_bg_color: this.flairBgColor,
      primary_group_flair_color: this.flairColor,
      primary_group_name: this.groupName
    };
  }
});
