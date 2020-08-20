import discourseComputed from "discourse-common/utils/decorators";
import Controller from "@ember/controller";

export default Controller.extend({
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
      .filter(t => t);
  }
});
