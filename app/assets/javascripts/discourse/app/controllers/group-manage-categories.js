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

  @discourseComputed(
    "model.watching_category_ids.[]",
    "model.watching_first_post_category_ids.[]",
    "model.tracking_category_ids.[]",
    "model.regular_category_ids.[]",
    "model.muted_category_ids.[]"
  )
  selectedCategoryIds(watching, watchingFirst, tracking, regular, muted) {
    return [].concat(watching, watchingFirst, tracking, regular, muted);
  },
});
