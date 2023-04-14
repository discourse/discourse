import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import I18n from "I18n";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { ajax } from "discourse/lib/ajax";
import { tracked } from "@glimmer/tracking";

export default class AdminCustomizeFormTemplateView extends Controller.extend(
  ModalFunctionality
) {
  @service router;
  @service dialog;
  @tracked showPreview = false;

  @action
  togglePreview() {
    this.showPreview = !this.showPreview;
  }

  @action
  editTemplate() {
    this.router.transitionTo("adminCustomizeFormTemplates.edit", this.model);
  }

  @action
  deleteTemplate() {
    return this.dialog.yesNoConfirm({
      message: I18n.t("admin.form_templates.delete_confirm", {
        template_name: this.model.name,
      }),
      didConfirm: () => {
        ajax(`/admin/customize/form-templates/${this.model.id}.json`, {
          type: "DELETE",
        })
          .then(() => {
            this.refreshModel();
          })
          .catch(popupAjaxError);
      },
    });
  }
}
