import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action, computed, set } from "@ember/object";
import { service } from "@ember/service";
import ConfirmSession from "discourse/components/dialog-messages/confirm-session";
import SecondFactorConfirmPhrase from "discourse/components/dialog-messages/second-factor-confirm-phrase";
import SecondFactorAddSecurityKey from "discourse/components/modal/second-factor-add-security-key";
import SecondFactorAddTotp from "discourse/components/modal/second-factor-add-totp";
import SecondFactorBackupEdit from "discourse/components/modal/second-factor-backup-edit";
import SecondFactorEdit from "discourse/components/modal/second-factor-edit";
import SecondFactorEditSecurityKey from "discourse/components/modal/second-factor-edit-security-key";
import { extractErrorInfo, popupAjaxError } from "discourse/lib/ajax-error";
import DiscourseURL, { userPath } from "discourse/lib/url";
import { escapeExpression } from "discourse/lib/utilities";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";
import { i18n } from "discourse-i18n";

export default class SecondFactorController extends Controller {
  @service dialog;
  @service modal;
  @service router;

  @tracked externalLoginRequired = false;
  @tracked localConfirmationRequired = false;
  @tracked factorsLoaded = false;

  loading = false;
  dirty = false;

  /** @type {string | null} */
  errorMessage = null;

  totps = [];
  security_keys = [];

  #factorLoadId = 0;

  @computed("model.second_factor_backup_enabled")
  get backupEnabled() {
    return this.model?.second_factor_backup_enabled;
  }

  set backupEnabled(value) {
    set(this, "model.second_factor_backup_enabled", value);
  }

  @computed("totps", "security_keys")
  get hasSecondFactors() {
    return this.totps.length > 0 || this.security_keys.length > 0;
  }

  @action
  async createTotp() {
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

  @action
  async createSecurityKey() {
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
    const errorType = error.responseJSON?.error_type;
    if (errorType === "second_factor_external_login_required") {
      this.modal.close();
      this.resetFactorLoad();
      this.externalLoginRequired = true;
    } else if (errorType === "invalid_access") {
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

  resetFactorLoad() {
    this.#factorLoadId++;
    this.setProperties({
      errorMessage: null,
      externalLoginRequired: false,
      factorsLoaded: false,
      localConfirmationRequired: false,
      loading: false,
      totps: [],
      security_keys: [],
    });
  }

  async loadSecondFactors({ onEntry = false, confirmOnEntry = false } = {}) {
    if (!this.dirty) {
      return;
    }

    this.resetFactorLoad();
    const loadId = this.#factorLoadId;
    this.set("loading", true);
    try {
      const response = await this.model.loadSecondFactorCodes();
      if (loadId !== this.#factorLoadId) {
        return;
      }

      this.set("dirty", false);
      if (response.external_login_required) {
        this.externalLoginRequired = true;
      } else if (response.unconfirmed_session) {
        this.localConfirmationRequired = true;
        if (confirmOnEntry) {
          this.confirmLocalSession();
        } else if (onEntry && !this.model.enforcedSecondFactor) {
          this.router.replaceWith("preferences.security");
        }
      } else {
        this.setProperties({
          factorsLoaded: true,
          totps: response.totps,
          security_keys: response.security_keys,
        });
      }
    } catch (error) {
      if (loadId === this.#factorLoadId) {
        const { message } = extractErrorInfo(error, error?.message, {
          skipConsoleError: true,
        });
        this.set("errorMessage", message);
      }
    } finally {
      if (loadId === this.#factorLoadId) {
        this.set("loading", false);
      }
    }
  }

  @action
  markDirty() {
    this.set("dirty", true);
  }

  @action
  confirmLocalSession() {
    this.dialog.dialog({
      title: i18n("user.confirm_access.title"),
      type: "notice",
      bodyComponent: ConfirmSession,
      didConfirm: () => {
        this.markDirty();
        this.loadSecondFactors();
      },
    });
  }

  @action
  disableAllSecondFactors() {
    if (this.model.requiresSecondFactor) {
      this.dialog.alert(i18n("user.second_factor.enforced_notice"));
      return;
    }

    if (this.loading || !this.factorsLoaded) {
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
        name: escapeExpression(secondFactorMethod.name),
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
          .catch((error) => this.handleError(error))
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
