import Controller from "@ember/controller";
import { action } from "@ember/object";
import { gt } from "@ember/object/computed";
import discourseComputed from "discourse-common/utils/decorators";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import logout from "discourse/lib/logout";
import showModal from "discourse/lib/show-modal";
import { userPath } from "discourse/lib/url";
import CanCheckEmails from "discourse/mixins/can-check-emails";
import I18n from "I18n";

// Number of tokens shown by default.
const DEFAULT_AUTH_TOKENS_COUNT = 2;

export default Controller.extend(CanCheckEmails, {
  passwordProgress: null,
  subpageTitle: I18n.t("user.preferences_nav.security"),
  showAllAuthTokens: false,

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

  @action
  changePassword(event) {
    event?.preventDefault();
    if (!this.passwordProgress) {
      this.set("passwordProgress", I18n.t("user.change_password.in_progress"));
      return this.model
        .changePassword()
        .then(() => {
          // password changed
          this.setProperties({
            changePasswordProgress: false,
            passwordProgress: I18n.t("user.change_password.success"),
          });
        })
        .catch(() => {
          // password failed to change
          this.setProperties({
            changePasswordProgress: false,
            passwordProgress: I18n.t("user.change_password.error"),
          });
        });
    }
  },

  @action
  toggleShowAllAuthTokens(event) {
    event?.preventDefault();
    this.toggleProperty("showAllAuthTokens");
  },

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
  },

  actions: {
    save() {
      this.set("saved", false);

      return this.model
        .then(() => this.set("saved", true))
        .catch(popupAjaxError);
    },

    showToken(token) {
      showModal("auth-token", { model: token });
    },
  },
});
