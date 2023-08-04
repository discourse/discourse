import FilterModeMixin from "discourse/mixins/filter-mode";
import NavigationDefaultController from "discourse/controllers/navigation/default";

export default class CategoryController extends NavigationDefaultController.extend(
  FilterModeMixin
) {}
