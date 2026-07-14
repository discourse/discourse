import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import FormTemplateChooser from "discourse/select-kit/components/form-template-chooser";
import DEditor from "discourse/ui-kit/d-editor";
import DTextField from "discourse/ui-kit/d-text-field";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import { i18n } from "discourse-i18n";

export default class CategoryTopicTemplateEditor extends Component {
  @service currentUser;
  @service siteSettings;

  @tracked _showFormTemplateOverride;
  @tracked _localTopicTemplate;
  @tracked _localTopicTitlePlaceholder;

  get topicTemplate() {
    return this._localTopicTemplate ?? this.args.category?.topic_template;
  }

  set topicTemplate(value) {
    this._localTopicTemplate = value;
  }

  get topicTitlePlaceholder() {
    return (
      this._localTopicTitlePlaceholder ??
      this.args.category?.topic_title_placeholder
    );
  }

  set topicTitlePlaceholder(value) {
    this._localTopicTitlePlaceholder = value;
  }

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

    const formTemplateIds = this.args.category?.form_template_ids;
    return Boolean(formTemplateIds && formTemplateIds.length > 0);
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
      if (this.args.onChange) {
        this.args.onChange("form_template_ids", []);
      } else {
        this.args.category.set("form_template_ids", []);
      }
    }
  }

  @action
  handleFormTemplateChange(value) {
    if (this.args.onChange) {
      this.args.onChange("form_template_ids", value);
    } else {
      this.args.category.set("form_template_ids", value);
    }
  }

  @action
  handleTopicTitlePlaceholderChange(value) {
    this.topicTitlePlaceholder = value;
    if (this.args.onChange) {
      this.args.onChange("topic_title_placeholder", value);
    } else {
      this.args.category.set("topic_title_placeholder", value);
    }
  }

  @action
  handleTopicTemplateChange(event) {
    const value = event.target.value;
    this.topicTemplate = value;
    if (this.args.onChange) {
      this.args.onChange("topic_template", value);
    } else {
      this.args.category.set("topic_template", value);
    }
  }

  <template>
    <div class="control-group">
      <label for="category-topic-title-placeholder">
        {{i18n "category.topic_title_placeholder"}}
      </label>
      <DTextField
        @value={{this.topicTitlePlaceholder}}
        @id="category-topic-title-placeholder"
        @placeholderKey="category.topic_title_placeholder_placeholder"
        @onChange={{this.handleTopicTitlePlaceholderChange}}
      />
    </div>
    {{#if this.siteSettings.enable_form_templates}}
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
          @value={{this.topicTemplate}}
          @showLink={{this.showInsertLinkButton}}
          @change={{this.handleTopicTemplateChange}}
        />
      {{/if}}
    {{else}}
      <DEditor
        @value={{this.topicTemplate}}
        @showLink={{this.showInsertLinkButton}}
        @change={{this.handleTopicTemplateChange}}
      />
    {{/if}}
  </template>
}
