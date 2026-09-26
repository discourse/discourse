import { service } from "discourse/lib/service";
import DiscourseRoute from "discourse/routes/discourse";
import CategoryTypeChooserService from "discourse/services/category-type-chooser";

export default class NewCategoryIndex extends DiscourseRoute {
  @service(() => CategoryTypeChooserService) categoryTypeChooser;
  @service router;

  beforeModel() {
    if (!this.categoryTypeChooser.hasCompletedSetup) {
      this.router.replaceWith("newCategory.setup");
    } else {
      this.router.replaceWith("newCategory.tabs", "general");
    }
  }
}
