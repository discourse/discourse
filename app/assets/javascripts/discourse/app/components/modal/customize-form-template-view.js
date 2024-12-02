import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class CustomizeFormTemplateViewModal extends Component {
  @service router;
  @service dialog;
  @tracked showPreview = false;

  @action
  togglePreview() {
    this.showPreview = !this.showPreview;
  }

  @action
  editTemplate() {
    this.router.transitionTo(
      "adminCustomizeFormTemplates.edit",
      this.args.model
    );
  }

  @action
  deleteTemplate() {
    return this.dialog.yesNoConfirm({
      message: i18n("admin.form_templates.delete_confirm", {
        template_name: this.args.model.name,
      }),
      didConfirm: () => {
        ajax(`/admin/customize/form-templates/${this.args.model.id}.json`, {
          type: "DELETE",
        })
          .then(() => {
            this.args.refreshModel();
          })
          .catch(popupAjaxError);
      },
    });
  }
}
