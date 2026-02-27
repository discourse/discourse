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
    const result = await ajax("/categories/types");
    return result.types;
  }

  titleToken() {
    return i18n("category.create");
  }
}
