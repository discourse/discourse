import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class NewCategorySetup extends DiscourseRoute {
  @service categoryTypeChooser;
  @service router;

  beforeModel() {
    if (!this.categoryTypeChooser.isEnabled) {
      this.router.replaceWith("newCategory");
    }
  }

  async model() {
    return await ajax("/categories/types");
  }

  afterModel(model) {
    if (model.types.length === 1) {
      const type = model.types[0];
      this.categoryTypeChooser.choose(
        type.id,
        type.name,
        type.configuration_schema,
        type.title,
        model.counts[type.id]
      );
      this.router.transitionTo("newCategory.tabs", "general");
    }
  }

  titleToken() {
    return i18n("category.create");
  }
}
