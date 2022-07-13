import Controller, { inject as controller } from "@ember/controller";
import I18n from "I18n";
import discourseComputed, { observes } from "discourse-common/utils/decorators";

export default Controller.extend({
  application: controller(),
  user: controller(),
  userActionType: null,

  @observes("userActionType", "model.stream.itemsLoaded")
  _showFooter() {
    let showFooter;
    if (this.userActionType) {
      const stat = (this.get("model.stats") || []).find(
        (s) => s.action_type === this.userActionType
      );
      showFooter = stat && stat.count <= this.get("model.stream.itemsLoaded");
    } else {
      showFooter =
        this.get("model.statsCountNonPM") <=
        this.get("model.stream.itemsLoaded");
    }
    this.set("application.showFooter", showFooter);
  },

  @discourseComputed("model.pending_posts_count")
  pendingLabel(count) {
    return count > 0
      ? I18n.t("pending_posts.label_with_count", { count })
      : I18n.t("pending_posts.label");
  },
});
