import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
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

  _claimAbortController = null;
  _validatedInput = null;
  _editorTarget = null;

  constructor() {
    super(...arguments);
    this.appEvents.on("composer:replace-text", this, this.handleReplaceText);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.appEvents.off("composer:replace-text", this, this.handleReplaceText);
    this._claimAbortController?.abort();
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
  registerValidatedInput(element) {
    this._validatedInput = element;
  }

  @action
  handleInvalid() {
    this._editorTarget?.setAttribute("aria-invalid", "true");
    this._editorTarget?.setAttribute("aria-describedby", this.errorId);

    this.a11y.announce(
      i18n("form_templates.errors.value_missing.default"),
      "assertive"
    );
  }

  @action
  handleValidationInput(event) {
    if (event.currentTarget.validity.valid) {
      this._editorTarget?.setAttribute("aria-invalid", "false");
      this._editorTarget?.removeAttribute("aria-describedby");
    }
  }

  @action
  handleInput(event) {
    this.composerValue = event.target.value;
    next(this, () => {
      this.args.onChange?.(event);
      // the editor is not a form control, so the field backing it has to
      // announce the change for validation state to refresh
      this._validatedInput?.dispatchEvent(
        new Event("input", { bubbles: true })
      );
    });
  }

  @action
  onEditorSetup(textManipulation) {
    this._editorTarget =
      textManipulation.textarea || textManipulation.view?.dom;

    // the label is only rendered when the template defines one, so pointing at
    // it unconditionally would leave a dangling reference
    if (this.args.attributes?.label) {
      this._editorTarget?.setAttribute("aria-labelledby", this.labelId);
    }

    if (!this.args.uppyComposerUpload || !this.composer.allowUpload) {
      return;
    }

    this.args.uppyComposerUpload.textManipulation = textManipulation;

    const editorTarget = this._editorTarget;

    if (!editorTarget) {
      return;
    }

    this._claimAbortController?.abort();
    this._claimAbortController = new AbortController();
    const { signal } = this._claimAbortController;

    const claimUploadTarget = () => {
      this.args.uppyComposerUpload.textManipulation = textManipulation;
    };

    for (const event of ["focusin", "dragenter", "dragover"]) {
      editorTarget.addEventListener(event, claimUploadTarget, { signal });
    }
  }

  <template>
    <div class="control-group form-template-field" data-field-type="composer">
      {{#if @attributes.label}}
        <label id={{this.labelId}} class="form-template-field__label">
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
        @value={{this.composerValue}}
        @change={{this.handleInput}}
        @placeholder={{@attributes.placeholder}}
        @onSetup={{this.onEditorSetup}}
      />
      {{! must stay last: the error tip is only inserted after a field with no next sibling }}
      <input
        id={{this.validationInputId}}
        type="text"
        name={{@id}}
        value={{this.composerValue}}
        required={{if @validations.required "required" ""}}
        class="form-template-field__composer-hidden-input"
        tabindex="-1"
        aria-hidden="true"
        {{didInsert this.registerValidatedInput}}
        {{on "invalid" this.handleInvalid}}
        {{on "input" this.handleValidationInput}}
      />
    </div>
  </template>
}
