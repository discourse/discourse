import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import DEditor from "discourse/components/d-editor";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import FormTemplateChooser from "discourse/select-kit/components/form-template-chooser";
import { i18n } from "discourse-i18n";

export default class CategoryTopicTemplateEditor extends Component {
  @service currentUser;
  @service siteSettings;

  @tracked _showFormTemplateOverride;

  get showInsertLinkButton() {
    if (this.args.showInsertLinkButton === undefined) {
      return true;
    }
    return this.args.showInsertLinkButton;
  }

  get showFormTemplate() {
    if (this._showFormTemplateOverride !== undefined) {
      return this._showFormTemplateOverride;
    }
    return Boolean(
      this.args.category && this.args.category.get("form_template_ids.length")
    );
  }

  set showFormTemplate(value) {
    this._showFormTemplateOverride = value;
  }

  get templateTypeToggleLabel() {
    if (this.showFormTemplate) {
      return "admin.form_templates.edit_category.toggle_form_template";
    }

    return "admin.form_templates.edit_category.toggle_freeform";
  }

  @action
  toggleTemplateType() {
    this.showFormTemplate = !this.showFormTemplate;

    if (!this.showFormTemplate) {
      // Clear associated form templates if switching to freeform
      this.args.category.set("form_template_ids", []);
    }

    if (this.args.onChange) {
      this.args.onChange();
    }
  }

  @action
  handleFormTemplateChange(value) {
    this.args.category.set("form_template_ids", value);
    if (this.args.onChange) {
      this.args.onChange();
    }
  }

  <template>
    {{#if this.siteSettings.experimental_form_templates}}
      <div class="control-group">
        <DToggleSwitch
          class="toggle-template-type"
          @state={{this.showFormTemplate}}
          @label={{this.templateTypeToggleLabel}}
          {{on "click" this.toggleTemplateType}}
        />
      </div>

      {{#if this.showFormTemplate}}
        <div class="control-group">
          <FormTemplateChooser
            @value={{@category.form_template_ids}}
            @onChange={{this.handleFormTemplateChange}}
            class="select-category-template"
          />

          <p class="select-category-template__info desc">
            {{#if this.currentUser.staff}}
              <LinkTo @route="adminCustomizeFormTemplates">
                {{i18n
                  "admin.form_templates.edit_category.select_template_help"
                }}
              </LinkTo>
            {{/if}}
          </p>
        </div>
      {{else}}
        <DEditor
          @value={{@category.topic_template}}
          @showLink={{this.showInsertLinkButton}}
        />
      {{/if}}
    {{else}}
      <DEditor
        @value={{@category.topic_template}}
        @showLink={{this.showInsertLinkButton}}
      />
    {{/if}}
  </template>
}
