import discourseComputed from "discourse-common/utils/decorators";
import { inject } from "@ember/controller";
import NavigationDefaultController from "discourse/controllers/navigation/default";

export default NavigationDefaultController.extend({
  discoveryCategories: inject("discovery/categories"),

  @discourseComputed(
    "discoveryCategories.model",
    "discoveryCategories.model.draft"
  )
  draft() {
    return this.get("discoveryCategories.model.draft");
  }
});
