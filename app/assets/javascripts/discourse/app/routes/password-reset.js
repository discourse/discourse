import { ajax } from "discourse/lib/ajax";
import PreloadStore from "discourse/lib/preload-store";
import { userPath } from "discourse/lib/url";
import DiscourseRoute from "discourse/routes/discourse";
import { deepMerge } from "discourse-common/lib/object";
import { i18n } from "discourse-i18n";

export default class PasswordReset extends DiscourseRoute {
  titleToken() {
    return i18n("login.reset_password");
  }

  model(params) {
    if (PreloadStore.get("password_reset")) {
      return PreloadStore.getAndRemove("password_reset").then((json) =>
        deepMerge(params, json)
      );
    }
  }

  afterModel(model) {
    // confirm token here so email clients who crawl URLs don't invalidate the link
    if (model) {
      return ajax({
        url: userPath(`confirm-email-token/${model.token}.json`),
        dataType: "json",
      });
    }
  }

  setupController(controller) {
    super.setupController(...arguments);
    controller.initSelectedSecondFactorMethod();
  }
}
