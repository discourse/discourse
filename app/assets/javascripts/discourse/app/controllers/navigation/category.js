import NavigationDefaultController from "discourse/controllers/navigation/default";
import { calculateFilterMode } from "discourse/lib/filter-mode";
import { dependentKeyCompat } from "@ember/object/compat";
import { tracked } from "@glimmer/tracking";

export default class NavigationCategoryController extends NavigationDefaultController {
  @tracked category;
  @tracked filterType;
  @tracked noSubcategories;

  @dependentKeyCompat
  get filterMode() {
    return calculateFilterMode({
      category: this.category,
      filterType: this.filterType,
      noSubcategories: this.noSubcategories,
    });
  }
}
