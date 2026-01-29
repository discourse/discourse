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

  get formTemplateIds() {
    // DDAU mode: read from transientData if available
    if (this.args.transientData) {
      return this.args.transientData.form_template_ids ?? [];
    }
    // Legacy mode: read from category
    return this.args.category?.form_template_ids ?? [];
  }

  get topicTemplate() {
    // DDAU mode: read from transientData if available
    if (this.args.transientData) {
      return this.args.transientData.topic_template ?? "";
    }
    // Legacy mode: read from category
    return this.args.category?.topic_template ?? "";
  }

  set topicTemplate(value) {
    this.#setTopicTemplate(value);
  }

  get showFormTemplate() {
    if (this._showFormTemplateOverride !== undefined) {
      return this._showFormTemplateOverride;
    }
    return Boolean(this.formTemplateIds?.length);
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

  #setFormTemplateIds(value) {
    // DDAU mode: use form.set if available
    if (this.args.form) {
      this.args.form.set("form_template_ids", value);
    } else {
      // Legacy mode: mutate category directly
      this.args.category.set("form_template_ids", value);
    }

    if (this.args.onChange) {
      this.args.onChange();
    }
  }

  #setTopicTemplate(value) {
    // DDAU mode: use form.set if available
    if (this.args.form) {
      this.args.form.set("topic_template", value);
    } else {
      // Legacy mode: mutate category directly
      this.args.category.set("topic_template", value);
    }

    if (this.args.onChange) {
      this.args.onChange();
    }
  }

  @action
  toggleTemplateType() {
    this.showFormTemplate = !this.showFormTemplate;

    if (!this.showFormTemplate) {
      // Clear associated form templates if switching to freeform
      this.#setFormTemplateIds([]);
    }
  }

  @action
  handleFormTemplateChange(value) {
    this.#setFormTemplateIds(value);
  }

  @action
  handleTopicTemplateChange(event) {
    this.#setTopicTemplate(event?.target?.value ?? event);
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
            @value={{this.formTemplateIds}}
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
          @value={{this.topicTemplate}}
          @change={{this.handleTopicTemplateChange}}
          @showLink={{this.showInsertLinkButton}}
        />
      {{/if}}
    {{else}}
      <DEditor
        @value={{this.topicTemplate}}
        @change={{this.handleTopicTemplateChange}}
        @showLink={{this.showInsertLinkButton}}
      />
    {{/if}}
  </template>
}
