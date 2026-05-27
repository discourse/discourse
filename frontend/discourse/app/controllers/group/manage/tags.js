import Controller from "@ember/controller";
import { computed } from "@ember/object";

export default class GroupManageTagsController extends Controller {
  @computed(
    "model.watching_tags.[]",
    "model.watching_first_post_tags.[]",
    "model.tracking_tags.[]",
    "model.regular_tags.[]",
    "model.muted_tags.[]"
  )
  get selectedTags() {
    return []
      .concat(
        this.model?.watching_tags,
        this.model?.watching_first_post_tags,
        this.model?.tracking_tags,
        this.model?.regular_tags,
        this.model?.muted_tags
      )
      .filter((t) => t);
  }
}
