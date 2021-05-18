import NavigationDefaultController from "discourse/controllers/navigation/default";
import { inject } from "@ember/controller";

export default NavigationDefaultController.extend({
  discoveryCategories: inject("discovery/categories"),
});
