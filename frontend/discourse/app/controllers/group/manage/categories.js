import Controller from "@ember/controller";
import { computed } from "@ember/object";

export default class GroupManageCategoriesController extends Controller {
  @computed(
    "model.watchingCategories.[]",
    "model.watchingFirstPostCategories.[]",
    "model.trackingCategories.[]",
    "model.regularCategories.[]",
    "model.mutedCategories.[]"
  )
  get selectedCategories() {
    return []
      .concat(
        this.model?.watchingCategories,
        this.model?.watchingFirstPostCategories,
        this.model?.trackingCategories,
        this.model?.regularCategories,
        this.model?.mutedCategories
      )
      .filter(Boolean);
  }
}
