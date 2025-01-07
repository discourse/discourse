import { dependentKeyCompat } from "@ember/object/compat";
import { isEmpty } from "@ember/utils";
import { i18n } from "discourse-i18n";

export default class NameValidationHelper {
  constructor(owner) {
    this.owner = owner;
  }

  @dependentKeyCompat
  get nameTitle() {
    return i18n(
      this.owner.site.full_name_required_for_signup
        ? "user.name.title"
        : "user.name.title_optional"
    );
  }

  @dependentKeyCompat
  get nameValidation() {
    const accountName = this.owner.get("accountName");
    const forceValidationReason = this.owner.get("forceValidationReason");

    if (this.owner.site.full_name_required_for_signup && isEmpty(accountName)) {
      return {
        failed: true,
        ok: false,
        message: i18n("user.name.required"),
        reason: forceValidationReason ? i18n("user.name.required") : null,
        element: document.querySelector("#new-account-name"),
      };
    }

    return { ok: true };
  }
}
