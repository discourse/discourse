import Controller from "@ember/controller";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Controller.extend({
  saving: false,
  saved: false,

  actions: {
    save() {
      let priorities = {};
      this.get("settings.reviewable_score_types").forEach(st => {
        priorities[st.id] = parseFloat(st.reviewable_priority);
      });

      this.set("saving", true);
      ajax("/review/settings", {
        method: "PUT",
        data: { reviewable_priorities: priorities }
      })
        .then(() => {
          this.set("saved", true);
        })
        .catch(popupAjaxError)
        .finally(() => this.set("saving", false));
    }
  }
});
