import NavigationDefaultController from "discourse/controllers/navigation/default";
import { inject as controller } from "@ember/controller";

export default class NavigationCategoriesController extends NavigationDefaultController {
  @controller("discovery/categories") discoveryCategories;
}
