import Controller from "@ember/controller";
import discourseComputed from "discourse/lib/decorators";

export default class GroupManageCategoriesController extends Controller {
  @discourseComputed(
    "model.watchingCategories.[]",
    "model.watchingFirstPostCategories.[]",
    "model.trackingCategories.[]",
    "model.regularCategories.[]",
    "model.mutedCategories.[]"
  )
  selectedCategories(watching, watchingFirst, tracking, regular, muted) {
    return []
      .concat(watching, watchingFirst, tracking, regular, muted)
      .filter(Boolean);
  }
}
