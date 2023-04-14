import DiscourseRoute from "discourse/routes/discourse";
import I18n from "I18n";
import PreloadStore from "discourse/lib/preload-store";
import { deepMerge } from "discourse-common/lib/object";

export default DiscourseRoute.extend({
  titleToken() {
    return I18n.t("invites.accept_title");
  },

  model(params) {
    if (PreloadStore.get("invite_info")) {
      return PreloadStore.getAndRemove("invite_info").then((json) =>
        deepMerge(params, json)
      );
    } else {
      return {};
    }
  },

  setupController(controller, model) {
    this._super(...arguments);

    if (model.user_fields) {
      controller.userFields.forEach((userField) => {
        if (model.user_fields[userField.field.id]) {
          userField.value = model.user_fields[userField.field.id];
        }
      });
    }
  },
});
