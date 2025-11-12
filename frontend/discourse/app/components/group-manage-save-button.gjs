/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import GroupFlairVisibilityWarning from "discourse/components/group-flair-visibility-warning";
import GroupDefaultNotificationsModal from "discourse/components/modal/group-default-notifications";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed from "discourse/lib/decorators";
import { or } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class GroupManageSaveButton extends Component {
  @service modal;
  @service groupAutomaticMembersDialog;
  @service router;

  saving = null;
  disabled = false;
  updateExistingUsers = null;

  @discourseComputed("saving")
  savingText(saving) {
    return saving ? i18n("saving") : i18n("save");
  }

  @action
  setUpdateExistingUsers(value) {
    this.updateExistingUsers = value;
  }

  get shouldRenderWarningFlair() {
    return this.router.currentRouteName !== "group.manage.membership";
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
    {{#if this.shouldRenderWarningFlair}}
      <GroupFlairVisibilityWarning @model={{this.model}} />
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
