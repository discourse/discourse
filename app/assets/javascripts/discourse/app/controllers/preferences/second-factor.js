import DiscourseURL, { userPath } from "discourse/lib/url";
import CanCheckEmails from "discourse/mixins/can-check-emails";
import Controller from "@ember/controller";
import I18n from "I18n";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";
import { action } from "@ember/object";
import { alias } from "@ember/object/computed";
import discourseComputed from "discourse-common/utils/decorators";
import { findAll } from "discourse/models/login-method";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { inject as service } from "@ember/service";
import SecondFactorConfirmPhrase from "discourse/components/dialog-messages/second-factor-confirm-phrase";
import SecondFactorAddSecurityKey from "discourse/components/modal/second-factor-add-security-key";
import SecondFactorEditSecurityKey from "discourse/components/modal/second-factor-edit-security-key";
import SecondFactorEdit from "discourse/components/modal/second-factor-edit";
import SecondFactorAddTotp from "discourse/components/modal/second-factor-add-totp";
import SecondFactorBackupEdit from "discourse/components/modal/second-factor-backup-edit";

export default Controller.extend(CanCheckEmails, {
  dialog: service(),
  modal: service(),
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

  loaded: false,

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

  @action
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

  @action
  setBackupEnabled(value) {
    this.set("backupEnabled", value);
  },

  @action
  setCodesRemaining(value) {
    this.model.set("second_factor_remaining_backup_codes", value);
  },

  @action
  loadSecondFactors() {
    if (this.dirty === false) {
      return;
    }
    this.set("loading", true);

    this.model
      .loadSecondFactorCodes(this.password)
      .then((response) => {
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
          dirty: false,
        });
        this.set(
          "model.second_factor_enabled",
          (response.totps && response.totps.length > 0) ||
            (response.security_keys && response.security_keys.length > 0)
        );
      })
      .catch((e) => this.handleError(e))
      .finally(() => this.set("loading", false));
  },

  @action
  markDirty() {
    this.set("dirty", true);
  },

  @action
  resetPassword(event) {
    event?.preventDefault();

    this.setProperties({
      resetPasswordLoading: true,
      resetPasswordProgress: "",
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

  actions: {
    confirmPassword() {
      if (!this.password) {
        return;
      }
      this.markDirty();
      this.loadSecondFactors();
      this.set("password", null);
    },

    disableAllSecondFactors() {
      if (this.loading) {
        return;
      }

      this.dialog.deleteConfirm({
        title: I18n.t("user.second_factor.disable_confirm"),
        bodyComponent: SecondFactorConfirmPhrase,
        bodyComponentModel: {
          totps: this.totps,
          security_keys: this.security_keys,
        },
        confirmButtonLabel: "user.second_factor.disable",
        confirmButtonDisabled: true,
        confirmButtonIcon: "ban",
        cancelButtonClass: "btn-flat",
        didConfirm: () => {
          this.model
            .disableAllSecondFactors()
            .then(() => {
              const usernameLower = this.model.username.toLowerCase();
              DiscourseURL.redirectTo(userPath(`${usernameLower}/preferences`));
            })
            .catch((e) => this.handleError(e))
            .finally(() => this.set("loading", false));
        },
      });
    },
    disableSingleSecondFactor(secondFactorMethod) {
      if (this.totps.concat(this.security_keys).length === 1) {
        this.send("disableAllSecondFactors");
        return;
      }
      this.dialog.deleteConfirm({
        title: I18n.t("user.second_factor.delete_single_confirm_title"),
        message: I18n.t("user.second_factor.delete_single_confirm_message", {
          name: secondFactorMethod.name,
        }),
        confirmButtonLabel: "user.second_factor.delete",
        confirmButtonIcon: "ban",
        cancelButtonClass: "btn-flat",
        didConfirm: () => {
          if (this.totps.includes(secondFactorMethod)) {
            this.currentUser
              .updateSecondFactor(
                secondFactorMethod.id,
                secondFactorMethod.name,
                true,
                secondFactorMethod.method
              )
              .then((response) => {
                if (response.error) {
                  return;
                }
                this.markDirty();
                this.set(
                  "totps",
                  this.totps.filter(
                    (totp) =>
                      totp.id !== secondFactorMethod.id ||
                      totp.method !== secondFactorMethod.method
                  )
                );
              })
              .catch((e) => this.handleError(e))
              .finally(() => {
                this.set("loading", false);
              });
          }

          if (this.security_keys.includes(secondFactorMethod)) {
            this.currentUser
              .updateSecurityKey(
                secondFactorMethod.id,
                secondFactorMethod.name,
                true
              )
              .then((response) => {
                if (response.error) {
                  return;
                }
                this.markDirty();
                this.set(
                  "security_keys",
                  this.security_keys.filter(
                    (securityKey) => securityKey.id !== secondFactorMethod.id
                  )
                );
              })
              .catch((e) => this.handleError(e))
              .finally(() => {
                this.set("loading", false);
              });
          }
        },
      });
    },
    disableSecondFactorBackup() {
      this.dialog.deleteConfirm({
        title: I18n.t("user.second_factor.delete_backup_codes_confirm_title"),
        message: I18n.t(
          "user.second_factor.delete_backup_codes_confirm_message"
        ),
        confirmButtonLabel: "user.second_factor.delete",
        confirmButtonIcon: "ban",
        cancelButtonClass: "btn-flat",
        didConfirm: () => {
          this.set("backupCodes", []);
          this.set("loading", true);

          this.model
            .updateSecondFactor(0, "", true, SECOND_FACTOR_METHODS.BACKUP_CODE)
            .then((response) => {
              if (response.error) {
                this.set("errorMessage", response.error);
                return;
              }

              this.set("errorMessage", null);
              this.model.set("second_factor_backup_enabled", false);
              this.markDirty();
              this.send("closeModal");
            })
            .catch((error) => {
              this.send("closeModal");
              this.onError(error);
            })
            .finally(() => this.set("loading", false));
        },
      });
    },

    async createTotp() {
      await this.modal.show(SecondFactorAddTotp, {
        model: {
          secondFactor: this.model,
          markDirty: () => this.markDirty(),
          onError: (e) => this.handleError(e),
        },
      });
      this.loadSecondFactors();
    },

    async createSecurityKey() {
      await this.modal.show(SecondFactorAddSecurityKey, {
        model: {
          secondFactor: this.model,
          markDirty: this.markDirty,
          onError: this.handleError,
        },
      });
      this.loadSecondFactors();
    },

    async editSecurityKey(security_key) {
      await this.modal.show(SecondFactorEditSecurityKey, {
        model: {
          securityKey: security_key,
          user: this.model,
          markDirty: () => this.markDirty(),
          onError: (e) => this.handleError(e),
        },
      });
      this.loadSecondFactors();
    },

    async editSecondFactor(second_factor) {
      await this.modal.show(SecondFactorEdit, {
        model: {
          secondFactor: second_factor,
          user: this.model,
          markDirty: () => this.markDirty(),
          onError: (e) => this.handleError(e),
        },
      });
      this.loadSecondFactors();
    },

    async editSecondFactorBackup() {
      await this.modal.show(SecondFactorBackupEdit, {
        model: {
          secondFactor: this.model,
          markDirty: () => this.markDirty(),
          onError: (e) => this.handleError(e),
          setBackupEnabled: (e) => this.setBackupEnabled(e),
          setCodesRemaining: (e) => this.setCodesRemaining(e),
        },
      });
    },
  },
});
