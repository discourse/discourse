import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { next, schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import DEditor from "discourse/ui-kit/d-editor";
import dIcon from "discourse/ui-kit/helpers/d-icon";

export default class FormTemplateFieldComposer extends Component {
  @service composer;
  @service appEvents;

  @tracked composerValue = this.args.value || "";

  _claimAbortController = null;
  _validatedInput = null;

  constructor() {
    super(...arguments);
    this.appEvents.on("composer:replace-text", this, this.handleReplaceText);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.appEvents.off("composer:replace-text", this, this.handleReplaceText);
    this._claimAbortController?.abort();
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
    if (!this.args.uppyComposerUpload || !this.composer.allowUpload) {
      return;
    }

    this.args.uppyComposerUpload.textManipulation = textManipulation;

    const editorTarget =
      textManipulation.textarea || textManipulation.view?.dom;
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
        <label class="form-template-field__label">
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
        type="text"
        name={{@id}}
        value={{this.composerValue}}
        required={{if @validations.required "required" ""}}
        class="form-template-field__composer-hidden-input"
        tabindex="-1"
        aria-hidden="true"
        {{didInsert this.registerValidatedInput}}
      />
    </div>
  </template>
}
