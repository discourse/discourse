import { observes } from "ember-addons/ember-computed-decorators";
import MountWidget from "discourse/components/mount-widget";

export default MountWidget.extend({
  widget: "avatar-flair",

  @observes("flairURL", "flairBgColor", "flairColor")
  _rerender() {
    this.queueRerender();
  },

  buildArgs() {
    return {
      primary_group_flair_url: this.get("flairURL"),
      primary_group_flair_bg_color: this.get("flairBgColor"),
      primary_group_flair_color: this.get("flairColor"),
      primary_group_name: this.get("groupName")
    };
  }
});
