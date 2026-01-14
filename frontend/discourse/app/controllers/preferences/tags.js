import Controller from "@ember/controller";
import { action } from "@ember/object";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed from "discourse/lib/decorators";
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

  @discourseComputed(
    "model.watched_tags.[]",
    "model.watching_first_post_tags.[]",
    "model.tracked_tags.[]",
    "model.muted_tags.[]"
  )
  selectedTags(watched, watchedFirst, tracked, muted) {
    return [].concat(watched, watchedFirst, tracked, muted).filter((t) => t);
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
