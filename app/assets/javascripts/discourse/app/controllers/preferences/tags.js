import Controller from "@ember/controller";
import { action } from "@ember/object";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed from "discourse/lib/decorators";

export default class TagsController extends Controller {
  saveAttrNames = [
    "muted_tags",
    "tracked_tags",
    "watched_tags",
    "watching_first_post_tags",
  ];

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
