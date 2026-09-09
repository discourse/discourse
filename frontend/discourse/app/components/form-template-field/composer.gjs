import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import { next, schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import DEditor from "discourse/ui-kit/d-editor";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class FormTemplateFieldComposer extends Component {
  @service composer;
  @service appEvents;
  @service a11y;

  @tracked composerValue = this.args.value || "";

  fieldUid = `form-template-composer-${guidFor(this)}`;

  #claimAbortController = null;
  #editorTarget = null;
  #validationFailed = false;

  constructor() {
    super(...arguments);
    this.appEvents.on("composer:replace-text", this, this.handleReplaceText);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.appEvents.off("composer:replace-text", this, this.handleReplaceText);
    this.#claimAbortController?.abort();
  }

  get labelId() {
    return `${this.fieldUid}-label`;
  }

  get validationInputId() {
    return `${this.fieldUid}-validation`;
  }

  // mirrors the id the shared form template validation gives the error tip
  get errorId() {
    return `${this.validationInputId}-error`;
  }

  @action
  handleReplaceText(oldVal, newVal) {
    if (!this.composerValue?.includes(oldVal)) {
      return;
    }

    this.composerValue = this.composerValue.replace(oldVal, newVal ?? "");

    schedule("afterRender", () => {
      this.args.onChange?.();
    });
  }

  @action
  handleInvalid() {
    this.#validationFailed = true;
    this.#syncEditorAccessibility();

    this.a11y.announce(
      i18n("form_templates.errors.value_missing.default"),
      "assertive"
    );
  }

  @action
  handleValidationInput(event) {
    if (event.currentTarget.validity.valid) {
      this.#validationFailed = false;
      this.#syncEditorAccessibility();
    }
  }

  @action
  handleInput(event) {
    this.composerValue = event.target.value;
    next(this, () => {
      this.args.onChange?.(event);
      // the editor emits no form events of its own, so the input standing in
      // for it has to report the change
      document
        .getElementById(this.validationInputId)
        ?.dispatchEvent(new Event("input", { bubbles: true }));
    });
  }

  @action
  onEditorSetup(textManipulation) {
    this.#editorTarget =
      textManipulation.textarea || textManipulation.view?.dom;

    this.#syncEditorAccessibility();

    if (!this.args.uppyComposerUpload || !this.composer.allowUpload) {
      return;
    }

    this.args.uppyComposerUpload.textManipulation = textManipulation;

    if (!this.#editorTarget) {
      return;
    }

    this.#claimAbortController?.abort();
    this.#claimAbortController = new AbortController();
    const { signal } = this.#claimAbortController;

    const claimUploadTarget = () => {
      this.args.uppyComposerUpload.textManipulation = textManipulation;
    };

    for (const event of ["focusin", "dragenter", "dragover"]) {
      this.#editorTarget.addEventListener(event, claimUploadTarget, { signal });
    }
  }

  // reapplies the full state rather than toggling it, because switching
  // between markdown and rich modes replaces the editor element
  #syncEditorAccessibility() {
    const editor = this.#editorTarget;

    if (!editor) {
      return;
    }

    // the label is only rendered when the template defines one
    if (this.args.attributes?.label) {
      editor.setAttribute("aria-labelledby", this.labelId);
    } else {
      editor.removeAttribute("aria-labelledby");
    }

    // the asterisk marking the field required is decorative, and the input
    // carrying `required` is hidden, so the editor has to state it itself
    if (this.args.validations?.required) {
      editor.setAttribute("aria-required", "true");
    } else {
      editor.removeAttribute("aria-required");
    }

    if (this.#validationFailed) {
      editor.setAttribute("aria-invalid", "true");
      editor.setAttribute("aria-describedby", this.errorId);
    } else {
      editor.removeAttribute("aria-invalid");
      editor.removeAttribute("aria-describedby");
    }
  }

  <template>
    <div class="control-group form-template-field" data-field-type="composer">
      {{#if @attributes.label}}
        <label class="form-template-field__label" id={{this.labelId}}>
          {{@attributes.label}}
          {{#if @validations.required}}
            {{dIcon "asterisk" class="form-template-field__required-indicator"}}
          {{/if}}
        </label>
      {{/if}}

      {{#if @attributes.description}}
        <span class="form-template-field__description">
          {{trustHTML @attributes.description}}
        </span>
      {{/if}}
      <DEditor
        class="form-template-field__composer"
        @change={{this.handleInput}}
        @onSetup={{this.onEditorSetup}}
        @placeholder={{@attributes.placeholder}}
        @value={{this.composerValue}}
      />
      {{! the editor is not a form control, so this stands in for it to carry the
      value and native validation. a textarea (not an input) is required so
      newlines survive value assignment — text inputs strip CR/LF per the HTML
      value-sanitisation rules, which flattens the composer preview on edit.
      must stay last: the error tip is only inserted after a field with no
      next sibling }}
      <textarea
        aria-hidden="true"
        class="form-template-field__composer-hidden-input"
        id={{this.validationInputId}}
        name={{@id}}
        required={{if @validations.required "required" ""}}
        tabindex="-1"
        value={{this.composerValue}}
        {{on "invalid" this.handleInvalid}}
        {{on "input" this.handleValidationInput}}
      ></textarea>
    </div>
  </template>
}
