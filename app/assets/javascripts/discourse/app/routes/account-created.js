import PreloadStore from "discourse/lib/preload-store";
import DiscourseRoute from "discourse/routes/discourse";
import I18n from "I18n";

export default DiscourseRoute.extend({
  titleToken() {
    return I18n.t("create_account.activation_title");
  },

  setupController(controller) {
    controller.set("accountCreated", PreloadStore.get("accountCreated"));
  },
});
