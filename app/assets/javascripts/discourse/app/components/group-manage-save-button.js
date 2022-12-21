import Component from "@ember/component";
import I18n from "I18n";
import discourseComputed from "discourse-common/utils/decorators";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { popupAutomaticMembershipAlert } from "discourse/controllers/groups-new";
import showModal from "discourse/lib/show-modal";
import { inject as service } from "@ember/service";

export default Component.extend({
  dialog: service(),
  saving: null,
  disabled: false,
  updateExistingUsers: null,

  didReceiveAttrs() {
    this._super(...arguments);

    const group = this.model;
    if (!group.buffer) {
      group.buffer = {
        visibilityLevel: group.visibility_level,
        primaryGroup: group.primary_group,
        flairEmpty: !(group.flair_icon || group.flair_upload_id),
      };
    }
  },

  @discourseComputed("saving")
  savingText(saving) {
    return saving ? I18n.t("saving") : I18n.t("save");
  },

  popupPrivateGroupNameAlert() {
    const model = this.model;
    const buffer = model.buffer;

    if (model.visibility_level === 0) {
      return;
    }

    const visibilityRestricted =
      model.visibility_level !== 0 && buffer.visibilityLevel === 0;

    if (model.primary_group && (visibilityRestricted || !buffer.primaryGroup)) {
      this.dialog.alert(
        I18n.t("admin.groups.manage.alert.primary_group", {
          group_name: model.name,
        })
      );
    } else if (
      (model.flair_icon || model.flair_upload_id) &&
      (visibilityRestricted || buffer.flairEmpty)
    ) {
      this.dialog.alert(
        I18n.t("admin.groups.manage.alert.flair_group", {
          group_name: model.name,
        })
      );
    }
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
      this.popupPrivateGroupNameAlert();

      const opts = {};
      if (this.updateExistingUsers !== null) {
        opts.update_existing_users = this.updateExistingUsers;
      }

      return group
        .save(opts)
        .then(() => {
          this.setProperties({
            saved: true,
            updateExistingUsers: null,
          });
          group.setProperties({
            buffer: {
              visibilityLevel: group.visibility_level,
              primaryGroup: group.primary_group,
              flairEmpty: !(group.flair_icon || group.flair_upload_id),
            },
          });

          if (this.afterSave) {
            this.afterSave();
          }
        })
        .catch((error) => {
          const json = error.jqXHR.responseJSON;
          if (error.jqXHR.status === 422 && json.user_count) {
            const controller = showModal("group-default-notifications", {
              model: { count: json.user_count },
            });

            controller.set("onClose", () => {
              this.updateExistingUsers = controller.updateExistingUsers;
              this.send("save");
            });
          } else {
            popupAjaxError(error);
          }
        })
        .finally(() => this.set("saving", false));
    },
  },
});
