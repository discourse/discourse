import { inject as controller } from "@ember/controller";
import { inject as service } from "@ember/service";
import NavigationDefaultController from "discourse/controllers/navigation/default";

export default class NavigationCategoriesController extends NavigationDefaultController {
  @service composer;
  @controller("discovery/categories") discoveryCategories;
}
