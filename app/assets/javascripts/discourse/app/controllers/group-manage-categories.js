import discourseComputed from "discourse-common/utils/decorators";
import Controller from "@ember/controller";

export default Controller.extend({
  @discourseComputed(
    "model.watchingCategories.[]",
    "model.watchingFirstPostCategories.[]",
    "model.trackingCategories.[]",
    "model.mutedCategories.[]"
  )
  selectedCategories(watching, watchingFirst, tracking, muted) {
    return [].concat(watching, watchingFirst, tracking, muted).filter(t => t);
  },
});
