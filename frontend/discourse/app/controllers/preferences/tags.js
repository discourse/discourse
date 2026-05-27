import Controller from "@ember/controller";
import { action, computed } from "@ember/object";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { applyValueTransformer } from "discourse/lib/transformer";

export default class TagsController extends Controller {
  get saveAttrNames() {
    return applyValueTransformer(
      "preferences-save-attributes",
      [
        "muted_tags",
        "tracked_tags",
        "watched_tags",
        "watching_first_post_tags",
      ],
      { page: "tags" }
    );
  }

  @computed(
    "model.watched_tags.[]",
    "model.watching_first_post_tags.[]",
    "model.tracked_tags.[]",
    "model.muted_tags.[]"
  )
  get selectedTags() {
    return []
      .concat(
        this.model?.watched_tags,
        this.model?.watching_first_post_tags,
        this.model?.tracked_tags,
        this.model?.muted_tags
      )
      .filter((t) => t);
  }

  @action
  save() {
    this.set("saved", false);
    return this.model
      .save(this.saveAttrNames)
      .then(() => {
        this.set("saved", true);
      })
      .catch(popupAjaxError);
  }
}
