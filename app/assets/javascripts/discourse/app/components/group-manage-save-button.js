import Component from "@ember/component";
import DiscourseURL from "discourse/lib/url";
import I18n from "I18n";
import discourseComputed from "discourse-common/utils/decorators";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { popupAutomaticMembershipAlert } from "discourse/controllers/groups-new";
import showModal from "discourse/lib/show-modal";

export default Component.extend({
  saving: null,
  disabled: false,
  updateExistingUsers: null,

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

      const opts = {};
      if (this.updateExistingUsers !== null) {
        opts.update_existing_users = this.updateExistingUsers;
      }

      return group
        .save(opts)
        .then((data) => {
          if (data.user_count) {
            const controller = showModal("group-default-notifications", {
              model: {
                count: data.user_count,
              },
            });

            controller.set("onClose", () => {
              this.updateExistingUsers = controller.updateExistingUsers;
              this.send("save");
            });

            return;
          }

          if (data.route_to) {
            DiscourseURL.routeTo(data.route_to);
          }

          this.setProperties({
            saved: true,
            updateExistingUsers: null,
          });

          if (this.afterSave) {
            this.afterSave();
          }
        })
        .catch(popupAjaxError)
        .finally(() => this.set("saving", false));
    },
  },
});
