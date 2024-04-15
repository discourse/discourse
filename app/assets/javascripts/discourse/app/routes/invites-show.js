import PreloadStore from "discourse/lib/preload-store";
import DiscourseRoute from "discourse/routes/discourse";
import { deepMerge } from "discourse-common/lib/object";
import I18n from "discourse-i18n";

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

  activate() {
    this._super(...arguments);

    this.controllerFor("application").setProperties({
      showSiteHeader: false,
    });
  },

  deactivate() {
    this._super(...arguments);

    this.controllerFor("application").setProperties({
      showSiteHeader: true,
    });
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
