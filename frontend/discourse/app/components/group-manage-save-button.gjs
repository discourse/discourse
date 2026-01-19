/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import GroupFlairVisibilityWarning from "discourse/components/group-flair-visibility-warning";
import GroupDefaultNotificationsModal from "discourse/components/modal/group-default-notifications";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { GROUP_VISIBILITY_LEVELS } from "discourse/lib/constants";
import discourseComputed from "discourse/lib/decorators";
import { defaultHomepage } from "discourse/lib/utilities";
import { or } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class GroupManageSaveButton extends Component {
  @service currentUser;
  @service dialog;
  @service modal;
  @service router;
  @service groupAutomaticMembersDialog;

  saving = null;
  disabled = false;

  @discourseComputed("saving")
  savingText(saving) {
    return saving ? i18n("saving") : i18n("save");
  }

  _wouldLoseAccess() {
    if (this.currentUser.admin) {
      return false;
    }

    const group = this.model;

    if (
      group.visibility_level === GROUP_VISIBILITY_LEVELS.owners ||
      group.members_visibility_level === GROUP_VISIBILITY_LEVELS.owners
    ) {
      return !group.is_group_owner_display;
    }

    return false;
  }

  @action
  async save(updateExistingUsers = null) {
    if (this.beforeSave) {
      this.beforeSave();
    }

    const lostAccess = this._wouldLoseAccess();

    if (lostAccess) {
      const confirmed = await this.dialog.yesNoConfirm({
        message: i18n("groups.manage.interaction.self_lockout"),
      });

      if (!confirmed) {
        return;
      }
    }

    const group = this.model;

    const accepted = await this.groupAutomaticMembersDialog.showConfirm(
      group.id,
      group.automatic_membership_email_domains
    );

    if (!accepted) {
      return;
    }

    this.set("saving", true);

    const opts = {};
    if (updateExistingUsers !== null) {
      opts.update_existing_users = updateExistingUsers;
    }

    try {
      await group.save(opts);

      if (lostAccess) {
        this.router.transitionTo(`discovery.${defaultHomepage()}`);
        return;
      }

      this.set("saved", true);

      if (this.afterSave) {
        this.afterSave();
      }
    } catch (error) {
      const json = error.jqXHR?.responseJSON;
      if (error.jqXHR?.status === 422 && json?.user_count) {
        this.editGroupNotifications(json.user_count);
      } else {
        popupAjaxError(error);
      }
    } finally {
      this.set("saving", false);
    }
  }

  @action
  async editGroupNotifications(count) {
    const updateExistingUsers = await this.modal.show(
      GroupDefaultNotificationsModal,
      { model: { count } }
    );
    this.save(updateExistingUsers);
  }

  <template>
    <GroupFlairVisibilityWarning @model={{this.model}} />

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
