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

    // NOTE (martin) This was previously consume() which got rid of the selection
    // of category type in memory, but model() is called every time the tab is changed
    // when creating a new category, so we need to keep the selection in memory.
    //
    // categoryTypeChooser is reset when leaving the newCategory route anyway.
    const result = this.categoryTypeChooser.currentSelection();
    if (result) {
      const initialTypes = {};
      initialTypes[result.type] = {
        id: result.type,
        name: result.typeName,
        configuration_schema: result.typeSchema,
        title: result.typeTitle,
      };
      model.set("categoryTypes", initialTypes);

      // Only want to prefill the general settings (name etc) if it's the
      // first category of this type.
      if ((result.count ?? 0) === 0) {
        result.typeSchema.general_category_settings?.forEach((setting) => {
          model.set(setting.key, setting.default);
        });
      }
    }

    const selectedTab = transition.to.params.tab;
    controller.setProperties({
      parentParams: {},
      showTooltip: false,
    });
    controller.initFormData();
    controller.setSelectedTab(selectedTab);
  }
}
