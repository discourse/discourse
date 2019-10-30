import { default as computed } from "ember-addons/ember-computed-decorators";
import Mixin from '@ember/object/mixin';

export default Mixin.create({
  saved: false,

  @computed("model.isSaving")
  saveButtonText(isSaving) {
    return isSaving ? I18n.t("saving") : I18n.t("save");
  }
});
