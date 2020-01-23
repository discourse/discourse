import { isEmpty } from "@ember/utils";
import discourseComputed from "discourse-common/utils/decorators";
import Mixin from "@ember/object/mixin";
import EmberObject from "@ember/object";

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
      count: this.passwordMinLength
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
    "passwordMinLength"
  )
  passwordValidation(
    password,
    passwordRequired,
    rejectedPasswords,
    accountUsername,
    accountEmail,
    passwordMinLength
  ) {
    if (!passwordRequired) {
      return EmberObject.create({ ok: true });
    }

    if (rejectedPasswords.includes(password)) {
      return EmberObject.create({
        failed: true,
        reason:
          this.rejectedPasswordsMessages.get(password) ||
          I18n.t("user.password.common")
      });
    }

    // If blank, fail without a reason
    if (isEmpty(password)) {
      return EmberObject.create({ failed: true });
    }

    // If too short
    if (password.length < passwordMinLength) {
      return EmberObject.create({
        failed: true,
        reason: I18n.t("user.password.too_short")
      });
    }

    if (!isEmpty(accountUsername) && password === accountUsername) {
      return EmberObject.create({
        failed: true,
        reason: I18n.t("user.password.same_as_username")
      });
    }

    if (!isEmpty(accountEmail) && password === accountEmail) {
      return EmberObject.create({
        failed: true,
        reason: I18n.t("user.password.same_as_email")
      });
    }

    // Looks good!
    return EmberObject.create({
      ok: true,
      reason: I18n.t("user.password.ok")
    });
  }
});
