import { tracked } from "@glimmer/tracking";
import EmberObject from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { TrackedArray, TrackedMap } from "@ember-compat/tracked-built-ins";
import { i18n } from "discourse-i18n";

export default class PasswordValidationHelper {
  @service siteSettings;
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
      ? this.siteSettings.min_admin_password_length
      : this.siteSettings.min_password_length;
  }

  @dependentKeyCompat
  get passwordValidation() {
    const failedAttrs = {
      failed: true,
      ok: false,
      element: document.querySelector("#new-account-password"),
    };

    if (!this.owner.passwordRequired) {
      return EmberObject.create({ ok: true });
    }

    if (this.rejectedPasswords.includes(this.owner.accountPassword)) {
      return EmberObject.create(
        Object.assign(failedAttrs, {
          reason:
            this.rejectedPasswordsMessages.get(this.owner.accountPassword) ||
            i18n("user.password.common"),
        })
      );
    }

    // If blank, fail without a reason
    if (isEmpty(this.owner.accountPassword)) {
      return EmberObject.create(
        Object.assign(failedAttrs, {
          message: i18n("user.password.required"),
          reason: this.owner.forceValidationReason
            ? i18n("user.password.required")
            : null,
        })
      );
    }

    // If too short
    if (this.owner.accountPassword.length < this.passwordMinLength) {
      return EmberObject.create(
        Object.assign(failedAttrs, {
          reason: i18n("user.password.too_short", {
            count: this.passwordMinLength,
          }),
        })
      );
    }

    if (
      !isEmpty(this.owner.accountUsername) &&
      this.owner.accountPassword === this.owner.accountUsername
    ) {
      return EmberObject.create(
        Object.assign(failedAttrs, {
          reason: i18n("user.password.same_as_username"),
        })
      );
    }

    if (
      !isEmpty(this.owner.accountName) &&
      this.owner.accountPassword === this.owner.accountName
    ) {
      return EmberObject.create(
        Object.assign(failedAttrs, {
          reason: i18n("user.password.same_as_name"),
        })
      );
    }

    if (
      !isEmpty(this.owner.accountEmail) &&
      this.owner.accountPassword === this.owner.accountEmail
    ) {
      return EmberObject.create(
        Object.assign(failedAttrs, {
          reason: i18n("user.password.same_as_email"),
        })
      );
    }

    // Looks good!
    return EmberObject.create({
      ok: true,
      reason: i18n("user.password.ok"),
    });
  }
}
