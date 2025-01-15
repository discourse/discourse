import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { deepMerge } from "discourse/lib/object";
import PreloadStore from "discourse/lib/preload-store";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class InvitesShow extends DiscourseRoute {
  @service siteSettings;

  titleToken() {
    return i18n("invites.accept_title");
  }

  model(params) {
    if (PreloadStore.get("invite_info")) {
      return PreloadStore.getAndRemove("invite_info").then((json) =>
        deepMerge(params, json)
      );
    } else {
      return ajax(`/invites/${params.token}`).then((json) =>
        deepMerge(params, json)
      );
    }
  }

  activate() {
    super.activate(...arguments);

    if (this.siteSettings.login_required) {
      this.controllerFor("application").setProperties({
        showSiteHeader: false,
      });
    }
  }

  deactivate() {
    super.deactivate(...arguments);

    if (this.siteSettings.login_required) {
      this.controllerFor("application").setProperties({
        showSiteHeader: true,
      });
    }
  }

  setupController(controller, model) {
    super.setupController(...arguments);

    if (model.user_fields) {
      controller.userFields.forEach((userField) => {
        if (model.user_fields[userField.field.id]) {
          userField.value = model.user_fields[userField.field.id];
        }
      });
    }
  }
}
