import Controller, { inject as controller } from "@ember/controller";
import EmberObject, { action, computed } from "@ember/object";
import { alias, gt, not, or } from "@ember/object/computed";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import UserStatusModal from "discourse/components/modal/user-status";
import { popupAjaxError } from "discourse/lib/ajax-error";
import CanCheckEmailsHelper from "discourse/lib/can-check-emails-helper";
import { propertyNotEqual, setting } from "discourse/lib/computed";
import discourseComputed from "discourse/lib/decorators";
import { exportUserArchive } from "discourse/lib/export-csv";
import getURL from "discourse/lib/get-url";
import DiscourseURL from "discourse/lib/url";
import { findAll } from "discourse/models/login-method";
import { i18n } from "discourse-i18n";

export default class AccountController extends Controller {
  @service dialog;
  @service modal;
  @controller user;

  @setting("enable_names") canEditName;
  @setting("enable_user_status") canSelectUserStatus;
  @setting("moderators_view_emails") canModeratorsViewEmails;

  @alias("user.viewingSelf") canDownloadPosts;
  @not("currentUser.can_delete_account") cannotDeleteAccount;
  @or("model.isSaving", "deleting", "cannotDeleteAccount") deleteDisabled;
  @gt("model.availableTitles.length", 0) canSelectTitle;
  @gt("model.availableFlairs.length", 0) canSelectFlair;
  @propertyNotEqual("model.id", "currentUser.id") disableConnectButtons;

  canSaveUser = true;
  newNameInput = null;
  newTitleInput = null;
  newPrimaryGroupInput = null;
  newStatus = null;
  revoking = null;

  init() {
    super.init(...arguments);

    this.saveAttrNames = [
      "name",
      "title",
      "primary_group_id",
      "flair_group_id",
      "status",
    ];
    this.set("revoking", {});
  }

  reset() {
    this.set("passwordProgress", null);
  }

  @computed("model.id", "currentUser.id")
  get canCheckEmails() {
    return new CanCheckEmailsHelper(
      this.model.id,
      this.canModeratorsViewEmails,
      this.currentUser
    ).canCheckEmails;
  }

  @discourseComputed()
  nameInstructions() {
    return i18n(
      this.site.full_name_required_for_signup
        ? "user.name.instructions_required"
        : "user.name.instructions"
    );
  }

  @discourseComputed("model.filteredGroups")
  canSelectPrimaryGroup(primaryGroupOptions) {
    return (
      primaryGroupOptions.length > 0 &&
      this.siteSettings.user_selected_primary_groups
    );
  }

  @discourseComputed("model.associated_accounts")
  associatedAccountsLoaded(associatedAccounts) {
    return typeof associatedAccounts !== "undefined";
  }

  @discourseComputed("model.associated_accounts.[]")
  authProviders(accounts) {
    return findAll()
      .map((method) => ({
        method,
        account: accounts.find(({ name }) => name === method.name),
      }))
      .filter((value) => value.account || value.method.can_connect);
  }

  @discourseComputed(
    "model.email",
    "model.secondary_emails.[]",
    "model.unconfirmed_emails.[]"
  )
  emails(primaryEmail, secondaryEmails, unconfirmedEmails) {
    const emails = [];

    if (primaryEmail) {
      emails.push(
        EmberObject.create({
          email: primaryEmail,
          primary: true,
          confirmed: true,
        })
      );
    }

    if (secondaryEmails) {
      secondaryEmails.forEach((email) => {
        emails.push(EmberObject.create({ email, confirmed: true }));
      });
    }

    if (unconfirmedEmails) {
      unconfirmedEmails.forEach((email) => {
        emails.push(EmberObject.create({ email }));
      });
    }

    return emails.sort((a, b) => a.email.localeCompare(b.email));
  }

  @discourseComputed(
    "model.second_factor_enabled",
    "canCheckEmails",
    "model.is_anonymous"
  )
  canUpdateAssociatedAccounts(
    secondFactorEnabled,
    canCheckEmails,
    isAnonymous
  ) {
    if (secondFactorEnabled || !canCheckEmails || isAnonymous) {
      return false;
    }
    return findAll().length > 0;
  }

  @discourseComputed(
    "siteSettings.max_allowed_secondary_emails",
    "model.can_edit_email"
  )
  canAddEmail(maxAllowedSecondaryEmails, canEditEmail) {
    return maxAllowedSecondaryEmails > 0 && canEditEmail;
  }

  @action
  resendConfirmationEmail(email, event) {
    event?.preventDefault();
    email.set("resending", true);
    this.model
      .addEmail(email.email)
      .then(() => {
        email.set("resent", true);
      })
      .finally(() => {
        email.set("resending", false);
      });
  }

  @action
  showUserStatusModal(status) {
    this.modal.show(UserStatusModal, {
      model: {
        status,
        hidePauseNotifications: true,
        saveAction: (s) => this.set("newStatus", s),
        deleteAction: () => this.set("newStatus", null),
      },
    });
  }

  @action
  save() {
    this.set("saved", false);

    this.model.setProperties({
      name: this.newNameInput,
      title: this.newTitleInput,
      primary_group_id: this.newPrimaryGroupInput,
      flair_group_id: this.newFlairGroupId,
      status: this.newStatus,
    });

    return this.model
      .save(this.saveAttrNames)
      .then(() => this.set("saved", true))
      .catch(popupAjaxError);
  }

  @action
  setPrimaryEmail(email) {
    this.model.setPrimaryEmail(email).catch(popupAjaxError);
  }

  @action
  destroyEmail(email) {
    this.model.destroyEmail(email);
  }

  @action
  delete() {
    this.dialog.alert({
      message: i18n("user.delete_account_confirm"),
      buttons: [
        {
          icon: "triangle-exclamation",
          label: i18n("user.delete_account"),
          class: "btn-danger",
          action: () => {
            return this.model.delete().then(
              () => {
                next(() => {
                  this.dialog.alert({
                    message: i18n("user.deleted_yourself"),
                    didConfirm: () =>
                      DiscourseURL.redirectAbsolute(getURL("/")),
                    didCancel: () => DiscourseURL.redirectAbsolute(getURL("/")),
                  });
                });
              },
              () => {
                next(() =>
                  this.dialog.alert(i18n("user.delete_yourself_not_allowed"))
                );
                this.set("deleting", false);
              }
            );
          },
        },
        {
          label: i18n("composer.cancel"),
        },
      ],
    });
  }

  @action
  revokeAccount(account) {
    this.set(`revoking.${account.name}`, true);

    this.model
      .revokeAssociatedAccount(account.name)
      .then((result) => {
        if (result.success) {
          this.model.associated_accounts.removeObject(account);
        } else {
          this.dialog.alert(result.message);
        }
      })
      .catch(popupAjaxError)
      .finally(() => this.set(`revoking.${account.name}`, false));
  }

  @action
  connectAccount(method) {
    method.doLogin({ reconnect: true });
  }

  @action
  exportUserArchive() {
    this.dialog.yesNoConfirm({
      message: i18n("user.download_archive.confirm"),
      didConfirm: () => exportUserArchive(),
    });
  }
}
