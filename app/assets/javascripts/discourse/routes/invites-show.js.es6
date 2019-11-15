import DiscourseRoute from "discourse/routes/discourse";
import PreloadStore from "preload-store";

export default DiscourseRoute.extend({
  titleToken() {
    return I18n.t("invites.accept_title");
  },

  model(params) {
    if (PreloadStore.get("invite_info")) {
      return PreloadStore.getAndRemove("invite_info").then(json =>
        _.merge(params, json)
      );
    } else {
      return {};
    }
  }
});
