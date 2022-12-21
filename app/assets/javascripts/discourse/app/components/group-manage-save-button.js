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

  buffer: null,
  bufferId: null,

  didReceiveAttrs() {
    this._super(...arguments);

    const group = this.model;
    if (group.id !== this.bufferId) {
      this.setProperties({
        bufferId: group.id,
        buffer: {
          visibilityLevel: group.visibility_level,
          primaryGroup: group.primary_group,
          flairEmpty: !(group.flair_icon || group.flair_upload_id),
        },
      });
    }
  },

  @discourseComputed("saving")
  savingText(saving) {
    return saving ? I18n.t("saving") : I18n.t("save");
  },

  popupPrivateGroupNameAlert() {
    const { model, buffer } = this;
    if (model.visibility_level === 0 || buffer.visibilityLevel !== 0) {
      return;
    }

    if (model.primary_group && !buffer.primary_group) {
      this.dialog.alert(
        I18n.t("admin.groups.manage.primary_group_name_alert", {
          group_name: model.name,
        })
      );
    }

    if (buffer.flairEmpty && (model.flair_icon || model.flair_upload_id)) {
      this.dialog.alert(
        I18n.t("admin.groups.manage.flair_group_name_alert", {
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
