import NavigationDefaultController from "discourse/controllers/navigation/default";
import { inject as controller } from "@ember/controller";

export default NavigationDefaultController.extend({
  discoveryCategories: controller("discovery/categories"),
});
