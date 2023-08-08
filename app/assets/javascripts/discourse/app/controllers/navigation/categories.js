import NavigationDefaultController from "discourse/controllers/navigation/default";
import { inject as controller } from "@ember/controller";
import { inject as service } from "@ember/service";

export default class NavigationCategoriesController extends NavigationDefaultController {
  @service composer;
  @controller("discovery/categories") discoveryCategories;
}
