import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class EditCategoryTabs extends DiscourseRoute {
  @service router;

  model() {
    return this.modelFor("editCategory");
  }

  activate() {
    this.router.on("routeDidChange", this, this._syncTabFromParams);
  }

  deactivate() {
    this.router.off("routeDidChange", this, this._syncTabFromParams);
  }

  _syncTabFromParams() {
    if (this.router.currentRouteName?.startsWith("editCategory.tabs")) {
      const tab = this.router.currentRoute?.params?.tab;
      if (tab) {
        this.controllerFor("edit-category.tabs").setSelectedTab(tab);
      }
    }
  }

  setupController(controller, model, transition) {
    super.setupController(...arguments);

    const parentParams = this.paramsFor("editCategory");
    const selectedTab = transition.to.params.tab;

    controller.setProperties({
      parentParams,
      showTooltip: false,
    });

    controller.initFormData();
    controller.setSelectedTab(selectedTab);
  }
}
