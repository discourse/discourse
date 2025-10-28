import Controller from "@ember/controller";
import discourseComputed from "discourse/lib/decorators";

export default class GroupManageTagsController extends Controller {
  @discourseComputed(
    "model.watching_tags.[]",
    "model.watching_first_post_tags.[]",
    "model.tracking_tags.[]",
    "model.regular_tags.[]",
    "model.muted_tags.[]"
  )
  selectedTags(watching, watchingFirst, tracking, regular, muted) {
    return []
      .concat(watching, watchingFirst, tracking, regular, muted)
      .filter((t) => t);
  }
}
