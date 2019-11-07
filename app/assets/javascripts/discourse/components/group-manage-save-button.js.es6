import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Component.extend({
  saving: null,

  @discourseComputed("saving")
  savingText(saving) {
    if (saving) return I18n.t("saving");
    return saving ? I18n.t("saving") : I18n.t("save");
  },

  actions: {
    save() {
      this.set("saving", true);

      return this.model
        .save()
        .then(() => {
          this.set("saved", true);
        })
        .catch(popupAjaxError)
        .finally(() => this.set("saving", false));
    }
  }
});
