import Controller from "@ember/controller";
import { service } from "@ember/service";
import I18n from "discourse-i18n";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed from "discourse-common/utils/decorators";

export default Controller.extend({
  toats: service(),

  init() {
    this._super(...arguments);

    this.saveAttrNames = [
      "muted_tags",
      "tracked_tags",
      "watched_tags",
      "watching_first_post_tags",
    ];
  },

  @discourseComputed(
    "model.watched_tags.[]",
    "model.watching_first_post_tags.[]",
    "model.tracked_tags.[]",
    "model.muted_tags.[]"
  )
  selectedTags(watched, watchedFirst, tracked, muted) {
    return [].concat(watched, watchedFirst, tracked, muted).filter((t) => t);
  },

  actions: {
    save() {
      return this.model
        .save(this.saveAttrNames)
        .then(() => {
          this.toasts.success({
            duration: 3000,
            data: { message: I18n.t("saved") },
          });
        })
        .catch(popupAjaxError);
    },
  },
});
