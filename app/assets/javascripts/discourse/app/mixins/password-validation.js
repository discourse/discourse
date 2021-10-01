import EmberObject from "@ember/object";
import I18n from "I18n";
import Mixin from "@ember/object/mixin";
import discourseComputed from "discourse-common/utils/decorators";
import { isEmpty } from "@ember/utils";

export default Mixin.create({
  rejectedPasswords: null,

  init() {
    this._super(...arguments);
    this.set("rejectedPasswords", []);
    this.set("rejectedPasswordsMessages", new Map());
  },

  @discourseComputed("passwordMinLength")
  passwordInstructions() {
    return I18n.t("user.password.instructions", {
      count: this.passwordMinLength,
    });
  },

  @discourseComputed("isDeveloper", "admin")
  passwordMinLength(isDeveloper, admin) {
    return isDeveloper || admin
      ? this.siteSettings.min_admin_password_length
      : this.siteSettings.min_password_length;
  },

  @discourseComputed(
    "accountPassword",
    "passwordRequired",
    "rejectedPasswords.[]",
    "accountUsername",
    "accountEmail",
    "passwordMinLength",
    "forceValidationReason"
  )
  passwordValidation(
    password,
    passwordRequired,
    rejectedPasswords,
    accountUsername,
    accountEmail,
    passwordMinLength,
    forceValidationReason
  ) {
    const failedAttrs = {
      failed: true,
      ok: false,
      element: document.querySelector("#new-account-password"),
    };

    if (!passwordRequired) {
      return EmberObject.create({ ok: true });
    }

    if (rejectedPasswords.includes(password)) {
      return EmberObject.create(
        Object.assign(failedAttrs, {
          reason:
            this.rejectedPasswordsMessages.get(password) ||
            I18n.t("user.password.common"),
        })
      );
    }

    // If blank, fail without a reason
    if (isEmpty(password)) {
      return EmberObject.create(
        Object.assign(failedAttrs, {
          message: I18n.t("user.password.required"),
          reason: forceValidationReason
            ? I18n.t("user.password.required")
            : null,
        })
      );
    }

    // If too short
    if (password.length < passwordMinLength) {
      return EmberObject.create(
        Object.assign(failedAttrs, {
          reason: I18n.t("user.password.too_short"),
        })
      );
    }

    if (!isEmpty(accountUsername) && password === accountUsername) {
      return EmberObject.create(
        Object.assign(failedAttrs, {
          reason: I18n.t("user.password.same_as_username"),
        })
      );
    }

    if (!isEmpty(accountEmail) && password === accountEmail) {
      return EmberObject.create(
        Object.assign(failedAttrs, {
          reason: I18n.t("user.password.same_as_email"),
        })
      );
    }

    // Looks good!
    return EmberObject.create({
      ok: true,
      reason: I18n.t("user.password.ok"),
    });
  },
});
