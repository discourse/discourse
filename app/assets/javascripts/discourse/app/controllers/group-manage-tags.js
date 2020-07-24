import discourseComputed from "discourse-common/utils/decorators";
import Controller from "@ember/controller";

export default Controller.extend({
  @discourseComputed(
    "model.watching_tags.[]",
    "model.watching_first_post_tags.[]",
    "model.tracking_tags.[]",
    "model.muted_tags.[]"
  )
  selectedTags(watching, watchingFirst, tracking, muted) {
    return [].concat(watching, watchingFirst, tracking, muted).filter(t => t);
  },
});
