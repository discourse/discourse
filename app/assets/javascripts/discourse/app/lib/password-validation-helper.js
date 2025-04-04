import { tracked } from "@glimmer/tracking";
import { dependentKeyCompat } from "@ember/object/compat";
import { isEmpty } from "@ember/utils";
import { TrackedArray, TrackedMap } from "@ember-compat/tracked-built-ins";
import { i18n } from "discourse-i18n";

function failedResult(attrs) {
  return {
    failed: true,
    ok: false,
    element: document.querySelector("#new-account-password"),
    ...attrs,
  };
}

function validResult(attrs) {
  return { ok: true, ...attrs };
}

export default class PasswordValidationHelper {
  @tracked rejectedPasswords = new TrackedArray();
  @tracked rejectedPasswordsMessages = new TrackedMap();

  constructor({
    getAccountEmail,
    getAccountUsername,
    getAccountName,
    getAccountPassword,
    getPasswordRequired,
    getForceValidationReason,
    siteSettings,
    isAdminOrDeveloper,
  }) {
    this.getAccountEmail = getAccountEmail;
    this.getAccountUsername = getAccountUsername;
    this.getAccountName = getAccountName;
    this.getAccountPassword = getAccountPassword;
    this.getPasswordRequired = getPasswordRequired;
    this.getForceValidationReason = getForceValidationReason;
    this.siteSettings = siteSettings;
    this.isAdminOrDeveloper = isAdminOrDeveloper;
  }

  get passwordInstructions() {
    return i18n("user.password.instructions", {
      count: this.passwordMinLength,
    });
  }

  get passwordMinLength() {
    return this.isAdminOrDeveloper()
      ? this.siteSettings.min_admin_password_length
      : this.siteSettings.min_password_length;
  }

  @dependentKeyCompat
  get passwordValidation() {
    if (!this.getPasswordRequired()) {
      return validResult();
    }

    const password = this.getAccountPassword();

    if (this.rejectedPasswords.includes(password)) {
      return failedResult({
        reason:
          this.rejectedPasswordsMessages.get(password) ||
          i18n("user.password.common"),
      });
    }

    // If blank, fail without a reason
    if (isEmpty(password)) {
      return failedResult({
        message: i18n("user.password.required"),
        reason: this.getForceValidationReason()
          ? i18n("user.password.required")
          : null,
      });
    }

    // If too short
    if (password.length < this.passwordMinLength) {
      return failedResult({
        reason: i18n("user.password.too_short", {
          count: this.passwordMinLength,
        }),
      });
    }

    const passwordEqualValueChecks = [
      {
        value: this.getAccountUsername(),
        reason: "user.password.same_as_username",
      },
      { value: this.getAccountName(), reason: "user.password.same_as_name" },
      { value: this.getAccountEmail(), reason: "user.password.same_as_email" },
    ];

    for (const check of passwordEqualValueChecks) {
      if (!isEmpty(check.value) && password === check.value) {
        return failedResult({
          reason: i18n(check.reason),
        });
      }
    }

    return validResult({
      reason: i18n("user.password.ok"),
    });
  }
}
