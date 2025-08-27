import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import DModalCancel from "discourse/components/d-modal-cancel";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import Wrapper from "discourse/components/form-template-field/wrapper";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import HighlightedCode from "admin/components/highlighted-code";

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

  <template>
    <DModal
      @title={{@model.name}}
      @closeModal={{@closeModal}}
      class="customize-form-template-view-modal"
    >
      <:body>
        <div class="control-group">
          <DToggleSwitch
            class="form-templates__preview-toggle"
            @state={{this.showPreview}}
            @label="admin.form_templates.view_template.toggle_preview"
            {{on "click" this.togglePreview}}
          />
        </div>
        {{#if this.showPreview}}
          <Wrapper @id={{@model.id}} />
        {{else}}
          <HighlightedCode @lang="yaml" @code={{@model.template}} />
        {{/if}}
      </:body>

      <:footer>
        <DButton
          class="btn-primary"
          @action={{this.editTemplate}}
          @icon="pencil"
          @label="admin.form_templates.view_template.edit"
        />
        <DModalCancel @close={{@closeModal}} />
        <DButton
          class="btn-danger"
          @action={{this.deleteTemplate}}
          @icon="trash-can"
          @label="admin.form_templates.view_template.delete"
        />
      </:footer>
    </DModal>
  </template>
}
