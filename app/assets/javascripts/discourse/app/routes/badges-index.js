import Badge from "discourse/models/badge";
import DiscourseRoute from "discourse/routes/discourse";
import I18n from "I18n";
import PreloadStore from "discourse/lib/preload-store";
import { scrollTop } from "discourse/mixins/scroll-top";
import { action } from "@ember/object";

export default DiscourseRoute.extend({
  async model() {
    if (PreloadStore.get("badges")) {
      const json = await PreloadStore.getAndRemove("badges");
      return Badge.createFromJson(json);
    } else {
      return await Badge.findAll({ onlyListable: true });
    }
  },

  titleToken() {
    return I18n.t("badges.title");
  },

  @action
  didTransition() {
    this.controllerFor("application").set("showFooter", true);
    scrollTop();
    return true;
  },
});
