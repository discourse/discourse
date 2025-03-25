import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class FormTemplateRowItem extends Component {
  @service router;
  @service dialog;
  @service site;

  get activeCategories() {
    return this.site.categories?.filter((c) =>
      c["form_template_ids"].includes(this.args.template.id)
    );
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
      message: i18n("admin.form_templates.delete_confirm", {
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

<tr class="admin-list-item">
  <td class="col first">{{@template.name}}</td>
  <td class="col categories">
    {{#each this.activeCategories as |category|}}
      {{category-link category}}
    {{/each}}
  </td>
  <td class="col action">
    <DButton
      @title="admin.form_templates.list_table.actions.view"
      @icon="far-eye"
      @action={{fn (mut this.showViewTemplateModal) true}}
      class="btn-view-template"
    />
    <DButton
      @title="admin.form_templates.list_table.actions.edit"
      @icon="pencil"
      @action={{this.editTemplate}}
      class="btn-edit-template"
    />
    <DButton
      @title="admin.form_templates.list_table.actions.delete"
      @icon="trash-can"
      @action={{this.deleteTemplate}}
      class="btn-danger btn-delete-template"
    />
  </td>
</tr>

{{#if this.showViewTemplateModal}}
  <Modal::CustomizeFormTemplateView
    @closeModal={{fn (mut this.showViewTemplateModal) false}}
    @model={{@template}}
    @refreshModel={{@refreshModel}}
  />
{{/if}}