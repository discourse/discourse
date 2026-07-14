import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
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
  handleInput(event) {
    this.composerValue = event.target.value;
    next(this, () => {
      this.args.onChange?.(event);
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
      <input type="hidden" name={{@id}} value={{this.composerValue}} />
      <DEditor
        class="form-template-field__composer"
        @value={{this.composerValue}}
        @change={{this.handleInput}}
        @placeholder={{@attributes.placeholder}}
        @onSetup={{this.onEditorSetup}}
      />
    </div>
  </template>
}
