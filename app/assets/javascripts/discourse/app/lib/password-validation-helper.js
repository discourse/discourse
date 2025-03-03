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

  constructor(owner) {
    this.owner = owner;
  }

  get passwordInstructions() {
    return i18n("user.password.instructions", {
      count: this.passwordMinLength,
    });
  }

  get passwordMinLength() {
    return this.owner.admin || this.owner.isDeveloper
      ? this.owner.siteSettings.min_admin_password_length
      : this.owner.siteSettings.min_password_length;
  }

  @dependentKeyCompat
  get passwordValidation() {
    if (!this.owner.passwordRequired) {
      return validResult();
    }

    if (this.rejectedPasswords.includes(this.owner.accountPassword)) {
      return failedResult({
        reason:
          this.rejectedPasswordsMessages.get(this.owner.accountPassword) ||
          i18n("user.password.common"),
      });
    }

    // If blank, fail without a reason
    if (isEmpty(this.owner.accountPassword)) {
      return failedResult({
        message: i18n("user.password.required"),
        reason: this.owner.forceValidationReason
          ? i18n("user.password.required")
          : null,
      });
    }

    // If too short
    if (this.owner.accountPassword.length < this.passwordMinLength) {
      return failedResult({
        reason: i18n("user.password.too_short", {
          count: this.passwordMinLength,
        }),
      });
    }

    if (
      !isEmpty(this.owner.accountUsername) &&
      this.owner.accountPassword === this.owner.accountUsername
    ) {
      return failedResult({
        reason: i18n("user.password.same_as_username"),
      });
    }

    if (
      !isEmpty(this.owner.accountName) &&
      this.owner.accountPassword === this.owner.accountName
    ) {
      return failedResult({
        reason: i18n("user.password.same_as_name"),
      });
    }

    if (
      !isEmpty(this.owner.accountEmail) &&
      this.owner.accountPassword === this.owner.accountEmail
    ) {
      return failedResult({
        reason: i18n("user.password.same_as_email"),
      });
    }

    return validResult({
      reason: i18n("user.password.ok"),
    });
  }
}
