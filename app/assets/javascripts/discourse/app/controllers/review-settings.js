import Controller from "@ember/controller";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";

export default class ReviewSettingsController extends Controller {
  saving = false;
  saved = false;

  @action
  save() {
    let priorities = {};
    this.scoreTypes.forEach((st) => {
      priorities[st.id] = parseFloat(st.reviewable_priority);
    });

    this.set("saving", true);
    ajax("/review/settings", {
      type: "PUT",
      data: { reviewable_priorities: priorities },
    })
      .then(() => {
        this.set("saved", true);
      })
      .catch(popupAjaxError)
      .finally(() => this.set("saving", false));
  }

  @discourseComputed("settings.reviewable_score_types")
  scoreTypes(types) {
    const username = i18n("review.example_username");

    return types.map((type) => ({
      ...type,
      title: type.title.replace("%{username}", username),
    }));
  }
}
