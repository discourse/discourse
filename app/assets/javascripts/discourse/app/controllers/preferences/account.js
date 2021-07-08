import { gt, not, or } from "@ember/object/computed";
import { propertyNotEqual, setting } from "discourse/lib/computed";
import CanCheckEmails from "discourse/mixins/can-check-emails";
import Controller from "@ember/controller";
import EmberObject from "@ember/object";
import I18n from "I18n";
import bootbox from "bootbox";
import discourseComputed from "discourse-common/utils/decorators";
import { findAll } from "discourse/models/login-method";
import getURL from "discourse-common/lib/get-url";
import { iconHTML } from "discourse-common/lib/icon-library";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Controller.extend(CanCheckEmails, {
  init() {
    this._super(...arguments);

    this.saveAttrNames = [
      "name",
      "title",
      "primary_group_id",
      "flair_group_id",
    ];
    this.set("revoking", {});
  },

  canEditName: setting("enable_names"),
  canSaveUser: true,

  newNameInput: null,
  newTitleInput: null,
  newPrimaryGroupInput: null,

  revoking: null,

  cannotDeleteAccount: not("currentUser.can_delete_account"),
  deleteDisabled: or("model.isSaving", "deleting", "cannotDeleteAccount"),

  reset() {
    this.set("passwordProgress", null);
  },

  @discourseComputed()
  nameInstructions() {
    return I18n.t(
      this.siteSettings.full_name_required
        ? "user.name.instructions_required"
        : "user.name.instructions"
    );
  },

  canSelectTitle: gt("model.availableTitles.length", 0),
  canSelectFlair: gt("model.availableFlairs.length", 0),

  @discourseComputed("model.filteredGroups")
  canSelectPrimaryGroup(primaryGroupOptions) {
    return (
      primaryGroupOptions.length > 0 &&
      this.siteSettings.user_selected_primary_groups
    );
  },

  @discourseComputed("model.associated_accounts")
  associatedAccountsLoaded(associatedAccounts) {
    return typeof associatedAccounts !== "undefined";
  },

  @discourseComputed("model.associated_accounts.[]")
  authProviders(accounts) {
    const allMethods = findAll();

    const result = allMethods.map((method) => {
      return {
        method,
        account: accounts.find((account) => account.name === method.name), // Will be undefined if no account
      };
    });

    return result.filter((value) => value.account || value.method.can_connect);
  },

  disableConnectButtons: propertyNotEqual("model.id", "currentUser.id"),

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
  },

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
  },

  actions: {
    save() {
      this.set("saved", false);

      this.model.setProperties({
        name: this.newNameInput,
        title: this.newTitleInput,
        primary_group_id: this.newPrimaryGroupInput,
        flair_group_id: this.newFlairGroupId,
      });

      return this.model
        .save(this.saveAttrNames)
        .then(() => this.set("saved", true))
        .catch(popupAjaxError);
    },

    setPrimaryEmail(email) {
      this.model.setPrimaryEmail(email).catch(popupAjaxError);
    },

    destroyEmail(email) {
      this.model.destroyEmail(email);
    },

    resendConfirmationEmail(email) {
      email.set("resending", true);
      this.model
        .addEmail(email.email)
        .then(() => {
          email.set("resent", true);
        })
        .finally(() => {
          email.set("resending", false);
        });
    },

    delete() {
      this.set("deleting", true);
      const message = I18n.t("user.delete_account_confirm"),
        model = this.model,
        buttons = [
          {
            label: I18n.t("cancel"),
            class: "d-modal-cancel",
            link: true,
            callback: () => {
              this.set("deleting", false);
            },
          },
          {
            label:
              iconHTML("exclamation-triangle") + I18n.t("user.delete_account"),
            class: "btn btn-danger",
            callback() {
              model.delete().then(
                () => {
                  bootbox.alert(
                    I18n.t("user.deleted_yourself"),
                    () => (window.location = getURL("/"))
                  );
                },
                () => {
                  bootbox.alert(I18n.t("user.delete_yourself_not_allowed"));
                  this.set("deleting", false);
                }
              );
            },
          },
        ];
      bootbox.dialog(message, buttons, { classes: "delete-account" });
    },

    revokeAccount(account) {
      this.set(`revoking.${account.name}`, true);

      this.model
        .revokeAssociatedAccount(account.name)
        .then((result) => {
          if (result.success) {
            this.model.associated_accounts.removeObject(account);
          } else {
            bootbox.alert(result.message);
          }
        })
        .catch(popupAjaxError)
        .finally(() => this.set(`revoking.${account.name}`, false));
    },

    connectAccount(method) {
      method.doLogin({ reconnect: true });
    },
  },
});
