import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class NewCategoryTabs extends DiscourseRoute {
  @service categoryTypeChooser;
  @service router;

  controllerName = "edit-category.tabs";

  templateName = "edit-category.tabs";

  beforeModel() {
    if (
      this.categoryTypeChooser.isEnabled &&
      !this.categoryTypeChooser.hasCompletedSetup
    ) {
      this.router.replaceWith("newCategory.setup");
    }
  }

  model() {
    return this.modelFor("newCategory");
  }

  setupController(controller, model, transition) {
    super.setupController(...arguments);

    const result = this.categoryTypeChooser.consume();
    if (result) {
      controller.model.set("category_type", result.type);
      controller.model.set("category_type_name", result.typeName);
      controller.model.set("category_type_schema", result.typeSchema);
    }

    const selectedTab = transition.to.params.tab;
    controller.setProperties({
      parentParams: {},
      showTooltip: false,
    });
    controller.setSelectedTab(selectedTab);
  }
}
