import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action, get } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { waitForPromise } from "@ember/test-waiters";
import FormTemplate from "discourse/models/form-template";
import CheckboxField from "./checkbox.gjs";
import ComposerField from "./composer.gjs";
import DropdownField from "./dropdown.gjs";
import InputField from "./input.gjs";
import MultiSelectField from "./multi-select.gjs";
import TagChooserField from "./tag-chooser.gjs";
import TextareaField from "./textarea.gjs";
import UploadField from "./upload.gjs";

const FormTemplateField = <template>
  <@component
    @attributes={{@content.attributes}}
    @choices={{@content.choices}}
    @id={{@content.id}}
    @onChange={{@onChange}}
    @uppyComposerUpload={{@uppyComposerUpload}}
    @validations={{@content.validations}}
    @value={{@initialValue}}
  />
</template>;

export default class FormTemplateFieldWrapper extends Component {
  @service composer;
  @service siteSettings;

  /** @type {unknown} */
  @tracked error = null;

  /** @type {unknown} */
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
    composer: ComposerField,
  };

  #templateLoadSequence = 0;

  constructor() {
    super(...arguments);

    if (this.args.content) {
      // Content used when no id exists yet
      // (i.e. previewing while creating a new template)
      this.#loadTemplate(this.args.content);
    } else if (this.args.id) {
      this.#fetchTemplate(this.args.id);
    }

    next(this, () => {
      this.composer.set(
        "allowPreview",
        this.siteSettings.show_preview_for_form_templates
      );
    });
  }

  // child components expect an onChange function
  get onChange() {
    return this.args.onChange || (() => {});
  }

  @action
  refreshTemplate() {
    if (Array.isArray(this.args?.id) && this.args?.id.length === 0) {
      return;
    }

    return this.#fetchTemplate(this.args.id);
  }

  async #fetchTemplate(id) {
    const sequence = ++this.#templateLoadSequence;
    const response = await FormTemplate.findById(id);
    const templateContent = await response.form_template.template;
    return this.#loadTemplate(templateContent, id, sequence);
  }

  async #loadTemplate(
    templateContent,
    id = this.args.id,
    sequence = ++this.#templateLoadSequence
  ) {
    try {
      const promise = import("js-yaml");
      waitForPromise(promise);
      const { load } = await promise;
      if (
        sequence !== this.#templateLoadSequence ||
        id !== this.args.id ||
        this.isDestroying
      ) {
        return;
      }
      this.parsedTemplate = load(templateContent);
      this.args.onSelectFormTemplate?.(this.parsedTemplate, id);
    } catch (e) {
      this.error = e;
    }
  }

  <template>
    <div
      class="form-template-form__wrapper"
      {{didUpdate this.refreshTemplate @id}}
    >
      {{#if this.parsedTemplate}}
        {{#each this.parsedTemplate as |content|}}
          <FormTemplateField
            @component={{get this.fieldTypes content.type}}
            @content={{content}}
            @initialValue={{get this.initialValues content.id}}
            @onChange={{this.onChange}}
            @uppyComposerUpload={{@uppyComposerUpload}}
          />
        {{/each}}
      {{else if this.error}}
        <div class="alert alert-error">
          {{this.error}}
        </div>
      {{/if}}
    </div>
  </template>
}
