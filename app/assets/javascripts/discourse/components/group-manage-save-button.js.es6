import { popupAjaxError } from "discourse/lib/ajax-error";
import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  saving: null,

  @computed("saving")
  savingText(saving) {
    if (saving) return I18n.t("saving");
    return saving ? I18n.t("saving") : I18n.t("save");
  },

  actions: {
    save() {
      this.set("saving", true);

      return this.get("model")
        .save()
        .then(() => {
          this.set("saved", true);
        })
        .catch(popupAjaxError)
        .finally(() => this.set("saving", false));
    }
  }
});
