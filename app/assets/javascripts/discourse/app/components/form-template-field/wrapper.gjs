import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action, get } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import Yaml from "js-yaml";
import FormTemplate from "discourse/models/form-template";
import CheckboxField from "./checkbox";
import DropdownField from "./dropdown";
import InputField from "./input";
import MultiSelectField from "./multi-select";
import TagChooserField from "./tag-chooser";
import TextareaField from "./textarea";
import UploadField from "./upload";

const FormTemplateField = <template>
  <@component
    @id={{@content.id}}
    @attributes={{@content.attributes}}
    @choices={{@content.choices}}
    @validations={{@content.validations}}
    @value={{@initialValue}}
    @onChange={{@onChange}}
  />
</template>;

export default class FormTemplateFieldWrapper extends Component {
  @service composer;
  @service siteSettings;

  @tracked error = null;
  @tracked parsedTemplate = null;

  initialValues = this.args.initialValues ?? {};

  fieldTypes = {
    checkbox: CheckboxField,
    input: InputField,
    dropdown: DropdownField,
    "multi-select": MultiSelectField,
    textarea: TextareaField,
    "tag-chooser": TagChooserField,
    upload: UploadField,
  };

  constructor() {
    super(...arguments);

    if (this.args.content) {
      // Content used when no id exists yet
      // (i.e. previewing while creating a new template)
      this._loadTemplate(this.args.content);
    } else if (this.args.id) {
      this._fetchTemplate(this.args.id);
    }

    next(this, () => {
      this.composer.set(
        "allowPreview",
        this.siteSettings.show_preview_for_form_templates
      );
    });
  }

  _loadTemplate(templateContent) {
    try {
      this.parsedTemplate = Yaml.load(templateContent);

      this.args.onSelectFormTemplate?.(this.parsedTemplate);
    } catch (e) {
      this.error = e;
    }
  }

  @action
  refreshTemplate() {
    if (Array.isArray(this.args?.id) && this.args?.id.length === 0) {
      return;
    }

    return this._fetchTemplate(this.args.id);
  }

  async _fetchTemplate(id) {
    const response = await FormTemplate.findById(id);
    const templateContent = await response.form_template.template;
    return this._loadTemplate(templateContent);
  }

  <template>
    {{#if this.parsedTemplate}}
      <div
        class="form-template-form__wrapper"
        {{didUpdate this.refreshTemplate @id}}
      >
        {{#each this.parsedTemplate as |content|}}
          <FormTemplateField
            @component={{get this.fieldTypes content.type}}
            @content={{content}}
            @initialValue={{get this.initialValues content.id}}
            @onChange={{@onChange}}
          />
        {{/each}}
      </div>
    {{else if this.error}}
      <div class="alert alert-error">
        {{this.error}}
      </div>
    {{/if}}
  </template>
}
