import { alias, and } from "@ember/object/computed";
import Controller from "@ember/controller";
import discourseComputed from "discourse-common/utils/decorators";
import CanCheckEmails from "discourse/mixins/can-check-emails";
import DiscourseURL, { userPath } from "discourse/lib/url";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { findAll } from "discourse/models/login-method";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";
import showModal from "discourse/lib/show-modal";

export default Controller.extend(CanCheckEmails, {
  loading: false,
  dirty: false,
  resetPasswordLoading: false,
  resetPasswordProgress: "",
  password: null,
  errorMessage: null,
  newUsername: null,
  backupEnabled: alias("model.second_factor_backup_enabled"),
  secondFactorMethod: SECOND_FACTOR_METHODS.TOTP,
  totps: null,

  loaded: and("secondFactorImage", "secondFactorKey"),

  init() {
    this._super(...arguments);
    this.set("totps", []);
  },

  @discourseComputed
  displayOAuthWarning() {
    return findAll().length > 0;
  },

  @discourseComputed("currentUser")
  showEnforcedNotice(user) {
    return user && user.enforcedSecondFactor;
  },

  handleError(error) {
    if (error.jqXHR) {
      error = error.jqXHR;
    }
    let parsedJSON = error.responseJSON;
    if (parsedJSON.error_type === "invalid_access") {
      const usernameLower = this.model.username.toLowerCase();
      DiscourseURL.redirectTo(
        userPath(`${usernameLower}/preferences/second-factor`)
      );
    } else {
      popupAjaxError(error);
    }
  },

  loadSecondFactors() {
    if (this.dirty === false) {
      return;
    }
    this.set("loading", true);

    this.model
      .loadSecondFactorCodes(this.password)
      .then(response => {
        if (response.error) {
          this.set("errorMessage", response.error);
          return;
        }

        this.setProperties({
          errorMessage: null,
          loaded: true,
          totps: response.totps,
          security_keys: response.security_keys,
          password: null,
          dirty: false
        });
        this.set(
          "model.second_factor_enabled",
          (response.totps && response.totps.length > 0) ||
            (response.security_keys && response.security_keys.length > 0)
        );
      })
      .catch(e => this.handleError(e))
      .finally(() => this.set("loading", false));
  },

  markDirty() {
    this.set("dirty", true);
  },

  actions: {
    confirmPassword() {
      if (!this.password) return;
      this.markDirty();
      this.loadSecondFactors();
      this.set("password", null);
    },

    resetPassword() {
      this.setProperties({
        resetPasswordLoading: true,
        resetPasswordProgress: ""
      });

      return this.model
        .changePassword()
        .then(() => {
          this.set(
            "resetPasswordProgress",
            I18n.t("user.change_password.success")
          );
        })
        .catch(popupAjaxError)
        .finally(() => this.set("resetPasswordLoading", false));
    },

    disableAllSecondFactors() {
      if (this.loading) {
        return;
      }
      bootbox.confirm(
        I18n.t("user.second_factor.disable_confirm"),
        I18n.t("cancel"),
        I18n.t("user.second_factor.disable"),
        result => {
          if (result) {
            this.model
              .disableAllSecondFactors()
              .then(() => {
                const usernameLower = this.model.username.toLowerCase();
                DiscourseURL.redirectTo(
                  userPath(`${usernameLower}/preferences`)
                );
              })
              .catch(e => this.handleError(e))
              .finally(() => this.set("loading", false));
          }
        }
      );
    },

    createTotp() {
      const controller = showModal("second-factor-add-totp", {
        model: this.model,
        title: "user.second_factor.totp.add"
      });
      controller.setProperties({
        onClose: () => this.loadSecondFactors(),
        markDirty: () => this.markDirty(),
        onError: e => this.handleError(e)
      });
    },

    createSecurityKey() {
      const controller = showModal("second-factor-add-security-key", {
        model: this.model,
        title: "user.second_factor.security_key.add"
      });
      controller.setProperties({
        onClose: () => this.loadSecondFactors(),
        markDirty: () => this.markDirty(),
        onError: e => this.handleError(e)
      });
    },

    editSecurityKey(security_key) {
      const controller = showModal("second-factor-edit-security-key", {
        model: security_key,
        title: "user.second_factor.security_key.edit"
      });
      controller.setProperties({
        user: this.model,
        onClose: () => this.loadSecondFactors(),
        markDirty: () => this.markDirty(),
        onError: e => this.handleError(e)
      });
    },

    editSecondFactor(second_factor) {
      const controller = showModal("second-factor-edit", {
        model: second_factor,
        title: "user.second_factor.edit_title"
      });
      controller.setProperties({
        user: this.model,
        onClose: () => this.loadSecondFactors(),
        markDirty: () => this.markDirty(),
        onError: e => this.handleError(e)
      });
    },

    editSecondFactorBackup() {
      const controller = showModal("second-factor-backup-edit", {
        model: this.model,
        title: "user.second_factor_backup.title"
      });
      controller.setProperties({
        onClose: () => this.loadSecondFactors(),
        markDirty: () => this.markDirty(),
        onError: e => this.handleError(e)
      });
    }
  }
});
