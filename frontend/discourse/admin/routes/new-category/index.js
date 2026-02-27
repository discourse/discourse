import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class NewCategoryIndex extends DiscourseRoute {
  @service categoryTypeChooser;
  @service router;

  beforeModel() {
    if (
      this.categoryTypeChooser.isEnabled &&
      !this.categoryTypeChooser.hasCompletedSetup
    ) {
      this.router.replaceWith("newCategory.setup");
    } else {
      this.router.replaceWith("newCategory.tabs", "general");
    }
  }
}
