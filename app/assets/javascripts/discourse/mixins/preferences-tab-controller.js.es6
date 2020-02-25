import discourseComputed from "discourse-common/utils/decorators";
import Mixin from "@ember/object/mixin";

export default Mixin.create({
  saved: false,

  @discourseComputed("model.isSaving")
  saveButtonText(isSaving) {
    return isSaving ? I18n.t("saving") : I18n.t("save");
  }
});
