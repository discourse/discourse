import Component from "@ember/component";
import { action } from "@ember/object";
import { or as computedOr } from "@ember/object/computed";
import { service } from "@ember/service";
import { or } from "truth-helpers";
import DButton from "discourse/components/d-button";
import GroupDefaultNotificationsModal from "discourse/components/modal/group-default-notifications";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

export default class GroupManageSaveButton extends Component {
  @service modal;
  @service groupAutomaticMembersDialog;

  saving = null;
  disabled = false;
  updateExistingUsers = null;

  @computedOr("model.flair_icon", "model.flair_upload_id") hasFlair;

  @discourseComputed("saving")
  savingText(saving) {
    return saving ? i18n("saving") : i18n("save");
  }

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
      return i18n("admin.groups.manage.alert.primary_group", {
        group_name: this.model.name,
      });
    } else if (hasFlair) {
      return i18n("admin.groups.manage.alert.flair_group", {
        group_name: this.model.name,
      });
    }
  }

  @action
  setUpdateExistingUsers(value) {
    this.updateExistingUsers = value;
  }

  @action
  async save() {
    if (this.beforeSave) {
      this.beforeSave();
    }

    this.set("saving", true);
    const group = this.model;

    const accepted = await this.groupAutomaticMembersDialog.showConfirm(
      group.id,
      group.automatic_membership_email_domains
    );

    if (!accepted) {
      this.set("saving", false);
      return;
    }

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
  }

  @action
  async editGroupNotifications(json) {
    await this.modal.show(GroupDefaultNotificationsModal, {
      model: {
        count: json.user_count,
        setUpdateExistingUsers: this.setUpdateExistingUsers,
      },
    });
    this.save();
  }

  <template>
    {{#if this.privateGroupNameNotice}}
      <div class="row">
        <div class="alert alert-warning alert-private-group-name">
          {{this.privateGroupNameNotice}}
        </div>
      </div>
    {{/if}}
    <div class="control-group buttons group-manage-save-button">
      <DButton
        @action={{this.save}}
        @disabled={{or this.disabled this.saving}}
        @translatedLabel={{this.savingText}}
        class="btn-primary group-manage-save"
      />
      {{#if this.saved}}
        <span>{{i18n "saved"}}</span>
      {{/if}}
    </div>
  </template>
}
