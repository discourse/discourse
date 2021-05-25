import Component from "@ember/component";
import DiscourseURL from "discourse/lib/url";
import I18n from "I18n";
import discourseComputed from "discourse-common/utils/decorators";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { popupAutomaticMembershipAlert } from "discourse/controllers/groups-new";

export default Component.extend({
  saving: null,
  disabled: false,

  @discourseComputed("saving")
  savingText(saving) {
    return saving ? I18n.t("saving") : I18n.t("save");
  },

  actions: {
    save() {
      if (this.beforeSave) {
        this.beforeSave();
      }

      this.set("saving", true);
      const group = this.model;

      popupAutomaticMembershipAlert(
        group.id,
        group.automatic_membership_email_domains
      );

      return group
        .save()
        .then((data) => {
          if (data.route_to) {
            DiscourseURL.routeTo(data.route_to);
          }

          this.set("saved", true);

          if (this.afterSave) {
            this.afterSave();
          }
        })
        .catch(popupAjaxError)
        .finally(() => this.set("saving", false));
    },
  },
});
