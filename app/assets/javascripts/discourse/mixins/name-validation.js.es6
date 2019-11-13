import { isEmpty } from "@ember/utils";
import InputValidation from "discourse/models/input-validation";
import { default as discourseComputed } from "discourse-common/utils/decorators";
import Mixin from "@ember/object/mixin";

export default Mixin.create({
  @discourseComputed()
  nameInstructions() {
    return I18n.t(
      this.siteSettings.full_name_required
        ? "user.name.instructions_required"
        : "user.name.instructions"
    );
  },

  // Validate the name.
  @discourseComputed("accountName")
  nameValidation() {
    if (this.siteSettings.full_name_required && isEmpty(this.accountName)) {
      return InputValidation.create({ failed: true });
    }

    return InputValidation.create({ ok: true });
  }
});
