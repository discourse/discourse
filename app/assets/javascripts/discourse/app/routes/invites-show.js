import DiscourseRoute from "discourse/routes/discourse";
import I18n from "I18n";
import PreloadStore from "discourse/lib/preload-store";
import { deepMerge } from "discourse-common/lib/object";
import DisableSidebar from "discourse/mixins/disable-sidebar";

export default DiscourseRoute.extend(DisableSidebar, {
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
