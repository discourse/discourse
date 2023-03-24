import Component from "@glimmer/component";
import { action } from "@ember/object";
import showModal from "discourse/lib/show-modal";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import I18n from "I18n";

export default class FormTemplateRowItem extends Component {
  @service router;
  @service dialog;
  @service site;

  get activeCategories() {
    return this.site?.categories?.filter((c) =>
      c["form_template_ids"].includes(this.args.template.id)
    );
  }

  @action
  viewTemplate() {
    showModal("customize-form-template-view", {
      model: this.args.template,
      refreshModel: this.args.refreshModel,
    });
  }

  @action
  editTemplate() {
    this.router.transitionTo(
      "adminCustomizeFormTemplates.edit",
      this.args.template
    );
  }

  @action
  deleteTemplate() {
    return this.dialog.yesNoConfirm({
      message: I18n.t("admin.form_templates.delete_confirm", {
        template_name: this.args.template.name,
      }),
      didConfirm: () => {
        ajax(`/admin/customize/form-templates/${this.args.template.id}.json`, {
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
