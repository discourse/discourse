import Controller, { inject as controller } from "@ember/controller";
import EmberObject, { action, computed } from "@ember/object";
import { alias, gt, not, or } from "@ember/object/computed";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import UserStatusModal from "discourse/components/modal/user-status";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { removeValueFromArray } from "discourse/lib/array-tools";
import CanCheckEmailsHelper from "discourse/lib/can-check-emails-helper";
import { propertyNotEqual, setting } from "discourse/lib/computed";
import { exportUserArchive } from "discourse/lib/export-csv";
import getURL from "discourse/lib/get-url";
import { applyValueTransformer } from "discourse/lib/transformer";
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
    this.set("revoking", {});
  }

  get saveAttrNames() {
    return applyValueTransformer(
      "preferences-save-attributes",
      ["name", "title", "primary_group_id", "flair_group_id", "status"],
      { page: "account" }
    );
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

  @computed()
  get nameInstructions() {
    return i18n(
      this.site.full_name_required_for_signup
        ? "user.name.instructions_required"
        : "user.name.instructions"
    );
  }

  @computed("model.filteredGroups")
  get canSelectPrimaryGroup() {
    return (
      this.model?.filteredGroups?.length > 0 &&
      this.siteSettings.user_selected_primary_groups
    );
  }

  get associatedAccountsLoaded() {
    return typeof this.model.associated_accounts !== "undefined";
  }

  get authProviders() {
    return findAll()
      .map((method) => ({
        method,
        account: this.model.associated_accounts.find(
          ({ name }) => name === method.name
        ),
      }))
      .filter((value) => value.account || value.method.can_connect);
  }

  @computed(
    "model.email",
    "model.secondary_emails.[]",
    "model.unconfirmed_emails.[]"
  )
  get emails() {
    const emails = [];

    if (this.model?.email) {
      emails.push(
        EmberObject.create({
          email: this.model?.email,
          primary: true,
          confirmed: true,
        })
      );
    }

    if (this.model?.secondary_emails) {
      this.model?.secondary_emails.forEach((email) => {
        emails.push(EmberObject.create({ email, confirmed: true }));
      });
    }

    if (this.model?.unconfirmed_emails) {
      this.model?.unconfirmed_emails.forEach((email) => {
        emails.push(EmberObject.create({ email }));
      });
    }

    return emails.sort((a, b) => a.email.localeCompare(b.email));
  }

  @computed(
    "model.second_factor_enabled",
    "canCheckEmails",
    "model.is_anonymous"
  )
  get canUpdateAssociatedAccounts() {
    if (
      this.model?.second_factor_enabled ||
      !this.canCheckEmails ||
      this.model?.is_anonymous
    ) {
      return false;
    }
    return findAll().length > 0;
  }

  @computed("siteSettings.max_allowed_secondary_emails", "model.can_edit_email")
  get canAddEmail() {
    return (
      this.siteSettings?.max_allowed_secondary_emails > 0 &&
      this.model?.can_edit_email
    );
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
          removeValueFromArray(this.model.associated_accounts, account);
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
