import I18n from "I18n";
import DiscourseRoute from "discourse/routes/discourse";
import PreloadStore from "discourse/lib/preload-store";
import { merge } from "discourse-common/lib/object";

export default DiscourseRoute.extend({
  titleToken() {
    return I18n.t("invites.accept_title");
  },

  model(params) {
    if (PreloadStore.get("invite_info")) {
      return PreloadStore.getAndRemove("invite_info").then(json =>
        merge(params, json)
      );
    } else {
      return {};
    }
  }
});
