import Controller from "@ember/controller";
import discourseComputed from "discourse-common/utils/decorators";

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
      .filter((t) => t);
  },
});
