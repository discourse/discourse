import discourseComputed from "discourse-common/utils/decorators";
import Controller from "@ember/controller";

export default Controller.extend({
  @discourseComputed("model.isSaving")
  saveButtonText(isSaving) {
    return isSaving ? I18n.t("saving") : I18n.t("admin.customize.save");
  },

  @discourseComputed("model.changed", "model.isSaving")
  saveDisabled(changed, isSaving) {
    return !changed || isSaving;
  },

  actions: {
    save() {
      if (!this.model.saving) {
        this.set("saving", true);
        this.model
          .update(this.model.getProperties("html", "css"))
          .catch(e => {
            const msg =
              e.jqXHR.responseJSON && e.jqXHR.responseJSON.errors
                ? I18n.t("admin.customize.email_style.save_error_with_reason", {
                    error: e.jqXHR.responseJSON.errors.join(". ")
                  })
                : I18n.t("generic_error");
            bootbox.alert(msg);
          })
          .finally(() => this.set("model.changed", false));
      }
    }
  }
});
