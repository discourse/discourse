import { tracked } from "@glimmer/tracking";
import { dependentKeyCompat } from "@ember/object/compat";
import { isEmpty } from "@ember/utils";
import { i18n } from "discourse-i18n";

export default class NameValidationHelper {
  @tracked forceValidationReason = false;

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
    if (
      this.owner.site.full_name_required_for_signup &&
      isEmpty(this.owner.get("accountName"))
    ) {
      return {
        failed: true,
        ok: false,
        message: i18n("user.name.required"),
        reason: this.forceValidationReason ? i18n("user.name.required") : null,
        element: document.querySelector("#new-account-name"),
      };
    }

    return { ok: true };
  }
}
