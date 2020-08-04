import I18n from "I18n";
import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { popupAutomaticMembershipAlert } from "discourse/controllers/groups-new";

export default Component.extend({
  saving: null,

  @discourseComputed("saving")
  savingText(saving) {
    return saving ? I18n.t("saving") : I18n.t("save");
  },

  actions: {
    save() {
      this.set("saving", true);
      const group = this.model;

      popupAutomaticMembershipAlert(
        group.id,
        group.automatic_membership_email_domains
      );

      return group
        .save()
        .then(() => {
          this.set("saved", true);
        })
        .catch(popupAjaxError)
        .finally(() => this.set("saving", false));
    }
  }
});
