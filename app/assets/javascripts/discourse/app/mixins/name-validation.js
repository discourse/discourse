import { isEmpty } from "@ember/utils";
import discourseComputed from "discourse-common/utils/decorators";
import Mixin from "@ember/object/mixin";
import EmberObject from "@ember/object";

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
      return EmberObject.create({ failed: true });
    }

    return EmberObject.create({ ok: true });
  }
});
