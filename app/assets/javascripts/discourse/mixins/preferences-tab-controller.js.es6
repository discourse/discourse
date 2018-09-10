import { default as computed } from "ember-addons/ember-computed-decorators";

export default Ember.Mixin.create({
  saved: false,

  @computed("model.isSaving")
  saveButtonText(isSaving) {
    return isSaving ? I18n.t("saving") : I18n.t("save");
  }
});
