import { not, or, gt } from "@ember/object/computed";
import Controller from "@ember/controller";
import { iconHTML } from "discourse-common/lib/icon-library";
import CanCheckEmails from "discourse/mixins/can-check-emails";
import discourseComputed from "discourse-common/utils/decorators";
import PreferencesTabController from "discourse/mixins/preferences-tab-controller";
import { propertyNotEqual, setting } from "discourse/lib/computed";
import { popupAjaxError } from "discourse/lib/ajax-error";
import showModal from "discourse/lib/show-modal";
import { findAll } from "discourse/models/login-method";
import { ajax } from "discourse/lib/ajax";
import { userPath } from "discourse/lib/url";
import logout from "discourse/lib/logout";

// Number of tokens shown by default.
const DEFAULT_AUTH_TOKENS_COUNT = 2;

export default Controller.extend(CanCheckEmails, PreferencesTabController, {
  init() {
    this._super(...arguments);

    this.saveAttrNames = ["name", "title", "primary_group_id"];
    this.set("revoking", {});
  },

  canEditName: setting("enable_names"),
  canSaveUser: true,

  newNameInput: null,
  newTitleInput: null,
  newPrimaryGroupInput: null,

  passwordProgress: null,

  showAllAuthTokens: false,

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

  @discourseComputed("model.filteredGroups")
  canSelectPrimaryGroup(primaryGroupOptions) {
    return (
      primaryGroupOptions.length > 0 &&
      this.siteSettings.user_selected_primary_groups
    );
  },

  @discourseComputed("model.is_anonymous")
  canChangePassword(isAnonymous) {
    if (isAnonymous) {
      return false;
    } else {
      return (
        !this.siteSettings.enable_sso && this.siteSettings.enable_local_logins
      );
    }
  },

  @discourseComputed("model.associated_accounts")
  associatedAccountsLoaded(associatedAccounts) {
    return typeof associatedAccounts !== "undefined";
  },

  @discourseComputed("model.associated_accounts.[]")
  authProviders(accounts) {
    const allMethods = findAll();

    const result = allMethods.map(method => {
      return {
        method,
        account: accounts.find(account => account.name === method.name) // Will be undefined if no account
      };
    });

    return result.filter(value => value.account || value.method.can_connect);
  },

  disableConnectButtons: propertyNotEqual("model.id", "currentUser.id"),

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

  @discourseComputed("showAllAuthTokens", "model.user_auth_tokens")
  authTokens(showAllAuthTokens, tokens) {
    tokens.sort((a, b) => {
      if (a.is_active) {
        return -1;
      } else if (b.is_active) {
        return 1;
      } else {
        return b.seen_at.localeCompare(a.seen_at);
      }
    });

    return showAllAuthTokens
      ? tokens
      : tokens.slice(0, DEFAULT_AUTH_TOKENS_COUNT);
  },

  canShowAllAuthTokens: gt(
    "model.user_auth_tokens.length",
    DEFAULT_AUTH_TOKENS_COUNT
  ),

  actions: {
    save() {
      this.set("saved", false);

      this.model.setProperties({
        name: this.newNameInput,
        title: this.newTitleInput,
        primary_group_id: this.newPrimaryGroupInput
      });

      return this.model
        .save(this.saveAttrNames)
        .then(() => this.set("saved", true))
        .catch(popupAjaxError);
    },

    changePassword() {
      if (!this.passwordProgress) {
        this.set(
          "passwordProgress",
          I18n.t("user.change_password.in_progress")
        );
        return this.model
          .changePassword()
          .then(() => {
            // password changed
            this.setProperties({
              changePasswordProgress: false,
              passwordProgress: I18n.t("user.change_password.success")
            });
          })
          .catch(() => {
            // password failed to change
            this.setProperties({
              changePasswordProgress: false,
              passwordProgress: I18n.t("user.change_password.error")
            });
          });
      }
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
            }
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
                    () => (window.location = Discourse.getURL("/"))
                  );
                },
                () => {
                  bootbox.alert(I18n.t("user.delete_yourself_not_allowed"));
                  this.set("deleting", false);
                }
              );
            }
          }
        ];
      bootbox.dialog(message, buttons, { classes: "delete-account" });
    },

    revokeAccount(account) {
      this.set(`revoking.${account.name}`, true);

      this.model
        .revokeAssociatedAccount(account.name)
        .then(result => {
          if (result.success) {
            this.model.associated_accounts.removeObject(account);
          } else {
            bootbox.alert(result.message);
          }
        })
        .catch(popupAjaxError)
        .finally(() => this.set(`revoking.${account.name}`, false));
    },

    toggleShowAllAuthTokens() {
      this.toggleProperty("showAllAuthTokens");
    },

    revokeAuthToken(token) {
      ajax(
        userPath(
          `${this.get("model.username_lower")}/preferences/revoke-auth-token`
        ),
        {
          type: "POST",
          data: token ? { token_id: token.id } : {}
        }
      )
        .then(() => {
          if (!token) logout(); // All sessions revoked
        })
        .catch(popupAjaxError);
    },

    showToken(token) {
      showModal("auth-token", { model: token });
    },

    connectAccount(method) {
      method.doLogin({ reconnect: true });
    }
  }
});
