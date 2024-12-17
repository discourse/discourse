import Controller from "@ember/controller";
import { action } from "@ember/object";
import { alias } from "@ember/object/computed";
import { service } from "@ember/service";
import ConfirmSession from "discourse/components/dialog-messages/confirm-session";
import SecondFactorConfirmPhrase from "discourse/components/dialog-messages/second-factor-confirm-phrase";
import SecondFactorAddSecurityKey from "discourse/components/modal/second-factor-add-security-key";
import SecondFactorAddTotp from "discourse/components/modal/second-factor-add-totp";
import SecondFactorBackupEdit from "discourse/components/modal/second-factor-backup-edit";
import SecondFactorEdit from "discourse/components/modal/second-factor-edit";
import SecondFactorEditSecurityKey from "discourse/components/modal/second-factor-edit-security-key";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DiscourseURL, { userPath } from "discourse/lib/url";
import { findAll } from "discourse/models/login-method";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";
import discourseComputed from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";

export default class SecondFactorController extends Controller {
  @service dialog;
  @service modal;
  @service siteSettings;
  @service currentUser;

  loading = false;
  dirty = false;
  errorMessage = null;
  newUsername = null;

  @alias("model.second_factor_backup_enabled") backupEnabled;

  secondFactorMethod = SECOND_FACTOR_METHODS.TOTP;
  totps = [];
  security_keys = [];

  get isCurrentUser() {
    return this.currentUser.id === this.model.id;
  }

  @discourseComputed
  hasOAuth() {
    return findAll().length > 0;
  }

  @discourseComputed
  displayOAuthWarning() {
    return (
      this.hasOAuth && this.siteSettings.enforce_second_factor_on_external_auth
    );
  }

  @discourseComputed("currentUser")
  showEnforcedWithOAuthNotice(user) {
    return (
      user &&
      user.enforcedSecondFactor &&
      this.hasOAuth &&
      !this.siteSettings.enforce_second_factor_on_external_auth
    );
  }

  @discourseComputed("currentUser")
  showEnforcedNotice(user) {
    return (
      user &&
      user.enforcedSecondFactor &&
      this.siteSettings.enforce_second_factor_on_external_auth
    );
  }

  @discourseComputed("totps", "security_keys")
  hasSecondFactors(totps, security_keys) {
    return totps.length > 0 || security_keys.length > 0;
  }

  async createToTpModal() {
    try {
      await this.modal.show(SecondFactorAddTotp, {
        model: {
          secondFactor: this.model,
          enforcedSecondFactor: this.currentUser.enforcedSecondFactor,
          markDirty: () => this.markDirty(),
          onError: (e) => this.handleError(e),
        },
      });
      this.loadSecondFactors();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  async createSecurityKeyModal() {
    try {
      await this.modal.show(SecondFactorAddSecurityKey, {
        model: {
          secondFactor: this.model,
          enforcedSecondFactor: this.currentUser.enforcedSecondFactor,
          markDirty: this.markDirty,
          onError: this.handleError,
        },
      });
      this.loadSecondFactors();
    } catch (error) {
      popupAjaxError(error);
    }
  }

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
  }

  @action
  setBackupEnabled(value) {
    this.set("backupEnabled", value);
  }

  @action
  setCodesRemaining(value) {
    this.model.set("second_factor_remaining_backup_codes", value);
  }

  @action
  loadSecondFactors() {
    if (this.dirty === false) {
      return;
    }
    this.set("loading", true);

    this.model
      .loadSecondFactorCodes()
      .then((response) => {
        if (response.error) {
          this.set("errorMessage", response.error);
          return;
        }

        this.setProperties({
          errorMessage: null,
          totps: response.totps,
          security_keys: response.security_keys,
          dirty: false,
        });
      })
      .catch((e) => this.handleError(e))
      .finally(() => this.set("loading", false));
  }

  @action
  markDirty() {
    this.set("dirty", true);
  }

  @action
  async createTotp() {
    try {
      const trustedSession = await this.model.trustedSession();

      if (!trustedSession.success) {
        this.dialog.dialog({
          title: i18n("user.confirm_access.title"),
          type: "notice",
          bodyComponent: ConfirmSession,
          didConfirm: () => this.createToTpModal(),
        });
      } else {
        await this.createToTpModal();
      }
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async createSecurityKey() {
    try {
      const trustedSession = await this.model.trustedSession();

      if (!trustedSession.success) {
        this.dialog.dialog({
          title: i18n("user.confirm_access.title"),
          type: "notice",
          bodyComponent: ConfirmSession,
          didConfirm: () => this.createSecurityKeyModal(),
        });
      } else {
        await this.createSecurityKeyModal();
      }
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  disableAllSecondFactors() {
    if (this.loading) {
      return;
    }

    this.dialog.deleteConfirm({
      title: i18n("user.second_factor.disable_confirm"),
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
  }

  @action
  disableSingleSecondFactor(secondFactorMethod) {
    if (this.totps.concat(this.security_keys).length === 1) {
      this.send("disableAllSecondFactors");
      return;
    }
    this.dialog.deleteConfirm({
      title: i18n("user.second_factor.delete_single_confirm_title"),
      message: i18n("user.second_factor.delete_single_confirm_message", {
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
  }

  @action
  disableSecondFactorBackup() {
    this.dialog.deleteConfirm({
      title: i18n("user.second_factor.delete_backup_codes_confirm_title"),
      message: i18n("user.second_factor.delete_backup_codes_confirm_message"),
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
  }

  @action
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
  }

  @action
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
  }

  @action
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
  }
}
