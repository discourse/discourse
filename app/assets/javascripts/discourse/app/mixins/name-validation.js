import EmberObject from "@ember/object";
import Mixin from "@ember/object/mixin";
import { isEmpty } from "@ember/utils";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

export default Mixin.create({
  @discourseComputed()
  nameTitle() {
    return I18n.t(
      this.siteSettings.full_name_required
        ? "user.name.title"
        : "user.name.title_optional"
    );
  },

  // Validate the name.
  @discourseComputed("accountName", "forceValidationReason")
  nameValidation(accountName, forceValidationReason) {
    if (this.siteSettings.full_name_required && isEmpty(accountName)) {
      return EmberObject.create({
        failed: true,
        ok: false,
        message: I18n.t("user.name.required"),
        reason: forceValidationReason ? I18n.t("user.name.required") : null,
        element: document.querySelector("#new-account-name"),
      });
    }

    return EmberObject.create({ ok: true });
  },
});
