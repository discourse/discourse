import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Ember.Controller.extend({
  saving: false,
  saved: false,

  actions: {
    save() {
      let bonuses = {};
      this.get("settings.reviewable_score_types").forEach(st => {
        bonuses[st.id] = parseFloat(st.score_bonus);
      });

      this.set("saving", true);
      ajax("/review/settings", { method: "PUT", data: { bonuses } })
        .then(() => {
          this.set("saved", true);
        })
        .catch(popupAjaxError)
        .finally(() => this.set("saving", false));
    }
  }
});
