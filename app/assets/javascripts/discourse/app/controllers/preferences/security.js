import Controller from "@ember/controller";
import { action, computed } from "@ember/object";
import { gt } from "@ember/object/computed";
import { service } from "@ember/service";
import typeOf from "@ember/utils/lib/type-of";
import ConfirmSession from "discourse/components/dialog-messages/confirm-session";
import AuthTokenModal from "discourse/components/modal/auth-token";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import CanCheckEmailsHelper from "discourse/lib/can-check-emails-helper";
import { setting } from "discourse/lib/computed";
import discourseComputed from "discourse/lib/decorators";
import logout from "discourse/lib/logout";
import { userPath } from "discourse/lib/url";
import { isWebauthnSupported } from "discourse/lib/webauthn";
import { i18n } from "discourse-i18n";

// Number of tokens shown by default.
const DEFAULT_AUTH_TOKENS_COUNT = 2;

export default class SecurityController extends Controller {
  @service modal;
  @service dialog;
  @service router;
  @service currentUser;

  @setting("moderators_view_emails") canModeratorsViewEmails;

  passwordProgress = null;
  subpageTitle = i18n("user.preferences_nav.security");
  showAllAuthTokens = false;

  @gt("model.user_auth_tokens.length", DEFAULT_AUTH_TOKENS_COUNT)
  canShowAllAuthTokens;

  @computed("model.id", "currentUser.id")
  get canCheckEmails() {
    return new CanCheckEmailsHelper(
      this.model.id,
      this.canModeratorsViewEmails,
      this.currentUser
    ).canCheckEmails;
  }

  @computed("model.staged")
  get canResetPassword() {
    return !this.model.staged;
  }

  get isCurrentUser() {
    return this.currentUser?.id === this.model.id;
  }

  get canUsePasskeys() {
    return (
      !this.siteSettings.enable_discourse_connect &&
      this.siteSettings.enable_local_logins &&
      this.siteSettings.enable_passkeys &&
      isWebauthnSupported()
    );
  }

  @discourseComputed("model.is_anonymous")
  canChangePassword(isAnonymous) {
    if (isAnonymous) {
      return false;
    } else {
      return (
        !this.siteSettings.enable_discourse_connect &&
        this.siteSettings.enable_local_logins
      );
    }
  }

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
  }

  @action
  changePassword(event) {
    event?.preventDefault();
    if (!this.passwordProgress) {
      this.set("passwordProgress", i18n("user.change_password.in_progress"));
      return this.model
        .changePassword()
        .then(() => {
          // password changed
          this.setProperties({
            changePasswordProgress: false,
            passwordProgress: i18n("user.change_password.success"),
          });
        })
        .catch(() => {
          // password failed to change
          this.setProperties({
            changePasswordProgress: false,
            passwordProgress: i18n("user.change_password.error"),
          });
        });
    }
  }

  @discourseComputed(
    "model.is_anonymous",
    "model.no_password",
    "siteSettings",
    "model.user_passkeys",
    "model.associated_accounts"
  )
  canRemovePassword(
    isAnonymous,
    noPassword,
    siteSettings,
    userPasskeys,
    associatedAccounts
  ) {
    if (
      isAnonymous ||
      noPassword ||
      siteSettings.enable_discourse_connect ||
      !siteSettings.enable_local_logins
    ) {
      return false;
    }

    return (
      associatedAccounts?.length > 0 ||
      (this.canUsePasskeys && userPasskeys?.length > 0)
    );
  }

  @discourseComputed("model.associated_accounts")
  associatedAccountsLoaded(associatedAccounts) {
    return typeOf(associatedAccounts) !== "undefined";
  }

  removePasswordConfirm() {
    this.dialog.deleteConfirm({
      title: i18n("user.change_password.remove"),
      message: i18n("user.change_password.remove_detail"),
      confirmButtonLabel: "user.change_password.remove",
      confirmButtonIcon: "trash-can",
      didConfirm: () => {
        this.set("removePasswordInProgress", true);

        this.model
          .removePassword()
          .then((response) => {
            this.set("removePasswordInProgress", false);
            if (response.success) {
              this.model.set("no_password", true);
            }
          })
          .catch((error) => {
            this.set("removePasswordInProgress", false);
            popupAjaxError(error);
          });
      },
    });
  }

  @action
  async removePassword(event) {
    event?.preventDefault();
    if (this.removePasswordInProgress) {
      return;
    }

    try {
      const trustedSession = await this.model.trustedSession();

      if (!trustedSession.success) {
        this.dialog.dialog({
          title: i18n("user.confirm_access.title"),
          type: "notice",
          bodyComponent: ConfirmSession,
          didConfirm: () => this.removePasswordConfirm(),
        });
      } else {
        this.removePasswordConfirm();
      }
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  toggleShowAllAuthTokens(event) {
    event?.preventDefault();
    this.toggleProperty("showAllAuthTokens");
  }

  @action
  revokeAuthToken(token, event) {
    event?.preventDefault();
    ajax(
      userPath(
        `${this.get("model.username_lower")}/preferences/revoke-auth-token`
      ),
      {
        type: "POST",
        data: token ? { token_id: token.id } : {},
      }
    )
      .then(() => {
        if (!token) {
          logout();
        } // All sessions revoked
      })
      .catch(popupAjaxError);
  }

  @action
  async manage2FA() {
    try {
      const trustedSession = await this.model.trustedSession();

      if (!trustedSession.success) {
        this.dialog.dialog({
          title: i18n("user.confirm_access.title"),
          type: "notice",
          bodyComponent: ConfirmSession,
          didConfirm: () =>
            this.router.transitionTo("preferences.second-factor"),
        });
      } else {
        await this.router.transitionTo("preferences.second-factor");
      }
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  save() {
    this.set("saved", false);

    return this.model.then(() => this.set("saved", true)).catch(popupAjaxError);
  }

  @action
  showToken(token) {
    this.modal.show(AuthTokenModal, { model: token });
  }
}
