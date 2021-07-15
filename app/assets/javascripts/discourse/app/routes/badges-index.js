import Badge from "discourse/models/badge";
import DiscourseRoute from "discourse/routes/discourse";
import I18n from "I18n";
import PreloadStore from "discourse/lib/preload-store";
import { scrollTop } from "discourse/mixins/scroll-top";
import { action } from "@ember/object";

export default DiscourseRoute.extend({
  model() {
    if (PreloadStore.get("badges")) {
      return PreloadStore.getAndRemove("badges").then((json) =>
        Badge.createFromJson(json)
      );
    } else {
      return Badge.findAll({ onlyListable: true });
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
