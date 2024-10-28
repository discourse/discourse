import EmberObject, { computed } from "@ember/object";
import Mixin from "@ember/object/mixin";
import { isEmpty } from "@ember/utils";
import I18n from "discourse-i18n";

export default Mixin.create({
  rejectedPasswords: null,

  init() {
    this._super(...arguments);
    this.set("rejectedPasswords", []);
    this.set("rejectedPasswordsMessages", new Map());
  },

  passwordInstructions: computed("passwordMinLength", function () {
    return I18n.t("user.password.instructions", {
      count: this.passwordMinLength,
    });
  }),

  passwordMinLength: computed("isDeveloper", "admin", function () {
    const { isDeveloper, admin } = this;
    return isDeveloper || admin
      ? this.siteSettings.min_admin_password_length
      : this.siteSettings.min_password_length;
  }),

  passwordValidation: computed(
    "accountPassword",
    "passwordRequired",
    "rejectedPasswords.[]",
    "accountUsername",
    "accountEmail",
    "passwordMinLength",
    "forceValidationReason",
    function () {
      const failedAttrs = {
        failed: true,
        ok: false,
        element: document.querySelector("#new-account-password"),
      };

      if (!this.passwordRequired) {
        return EmberObject.create({ ok: true });
      }

      if (this.rejectedPasswords.includes(this.accountPassword)) {
        return EmberObject.create(
          Object.assign(failedAttrs, {
            reason:
              this.rejectedPasswordsMessages.get(this.accountPassword) ||
              I18n.t("user.password.common"),
          })
        );
      }

      // If blank, fail without a reason
      if (isEmpty(this.accountPassword)) {
        return EmberObject.create(
          Object.assign(failedAttrs, {
            message: I18n.t("user.password.required"),
            reason: this.forceValidationReason
              ? I18n.t("user.password.required")
              : null,
          })
        );
      }

      // If too short
      if (this.accountPassword.length < this.passwordMinLength) {
        return EmberObject.create(
          Object.assign(failedAttrs, {
            reason: I18n.t("user.password.too_short", {
              count: this.passwordMinLength,
            }),
          })
        );
      }

      if (
        !isEmpty(this.accountUsername) &&
        this.accountPassword === this.accountUsername
      ) {
        return EmberObject.create(
          Object.assign(failedAttrs, {
            reason: I18n.t("user.password.same_as_username"),
          })
        );
      }

      if (
        !isEmpty(this.accountEmail) &&
        this.accountPassword === this.accountEmail
      ) {
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
    }
  ),
});
