import InputValidation from "discourse/models/input-validation";
import { default as computed } from "ember-addons/ember-computed-decorators";

export default Ember.Mixin.create({
  @computed()
  nameInstructions() {
    return I18n.t(
      this.siteSettings.full_name_required
        ? "user.name.instructions_required"
        : "user.name.instructions"
    );
  },

  // Validate the name.
  @computed("accountName")
  nameValidation() {
    if (
      this.siteSettings.full_name_required &&
      Ember.isEmpty(this.get("accountName"))
    ) {
      return InputValidation.create({ failed: true });
    }

    return InputValidation.create({ ok: true });
  }
});
