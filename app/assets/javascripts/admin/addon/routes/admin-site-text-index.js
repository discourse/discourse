import Route from "@ember/routing/route";
import { action, getProperties } from "@ember/object";
import { inject as service } from "@ember/service";
import ReseedModal from "admin/components/modal/reseed";

export default class AdminSiteTextIndexRoute extends Route {
  @service modal;

  queryParams = {
    q: { replace: true },
    overridden: { replace: true },
    outdated: { replace: true },
    locale: { replace: true },
  };

  model(params) {
    return this.store.find(
      "site-text",
      getProperties(params, "q", "overridden", "outdated", "locale")
    );
  }

  setupController(controller, model) {
    controller.set("siteTexts", model);
  }

  @action
  showReseedModal() {
    this.modal.show(ReseedModal);
  }
}
