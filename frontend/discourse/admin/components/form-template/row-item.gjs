import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import CustomizeFormTemplateView from "discourse/components/modal/customize-form-template-view";
import categoryLink from "discourse/helpers/category-link";
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
    return this.dialog.deleteConfirm({
      title: i18n("admin.form_templates.delete_confirm", {
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

  <template>
    <tr class="admin-list-item">
      <td class="col first">{{@template.name}}</td>
      <td class="col categories">
        {{#each this.activeCategories as |category|}}
          {{categoryLink category}}
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
      <CustomizeFormTemplateView
        @closeModal={{fn (mut this.showViewTemplateModal) false}}
        @model={{@template}}
        @refreshModel={{@refreshModel}}
      />
    {{/if}}
  </template>
}
