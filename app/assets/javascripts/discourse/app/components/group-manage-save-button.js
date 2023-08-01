import Component from "@ember/component";
import I18n from "I18n";
import discourseComputed from "discourse-common/utils/decorators";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { popupAutomaticMembershipAlert } from "discourse/controllers/groups-new";
import { or } from "@ember/object/computed";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import GroupDefaultNotificationsModal from "discourse/components/modal/group-default-notifications";

export default Component.extend({
  modal: service(),
  saving: null,
  disabled: false,
  updateExistingUsers: null,
  hasFlair: or("model.flair_icon", "model.flair_upload_id"),

  @discourseComputed("saving")
  savingText(saving) {
    return saving ? I18n.t("saving") : I18n.t("save");
  },

  @discourseComputed(
    "model.visibility_level",
    "model.primary_group",
    "hasFlair"
  )
  privateGroupNameNotice(visibilityLevel, isPrimaryGroup, hasFlair) {
    if (visibilityLevel === 0) {
      return;
    }

    if (isPrimaryGroup) {
      return I18n.t("admin.groups.manage.alert.primary_group", {
        group_name: this.model.name,
      });
    } else if (hasFlair) {
      return I18n.t("admin.groups.manage.alert.flair_group", {
        group_name: this.model.name,
      });
    }
  },

  @action
  setUpdateExistingUsers(value) {
    this.updateExistingUsers = value;
  },

  @action
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
          this.editGroupNotifications(json);
        } else {
          popupAjaxError(error);
        }
      })
      .finally(() => this.set("saving", false));
  },

  @action
  async editGroupNotifications(json) {
    await this.modal.show(GroupDefaultNotificationsModal, {
      model: {
        count: json.user_count,
        setUpdateExistingUsers: this.setUpdateExistingUsers,
      },
    });
    this.save();
  },
});
