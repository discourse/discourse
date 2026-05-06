import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import DEditor from "discourse/ui-kit/d-editor";
import dIcon from "discourse/ui-kit/helpers/d-icon";

export default class FormTemplateFieldComposer extends Component {
  @service composer;

  @tracked composerValue = this.args.value || "";

  @action
  handleInput(event) {
    this.composerValue = event.target.value;
    next(this, () => {
      this.args.onChange?.(event);
    });
  }

  @action
  onEditorSetup(textManipulation) {
    if (
      !textManipulation.textarea ||
      !this.args.uppyComposerUpload ||
      !this.composer.allowUpload
    ) {
      return;
    }

    const element = textManipulation.textarea.closest(".d-editor");
    this.args.uppyComposerUpload.textManipulation = textManipulation;
    this.args.uppyComposerUpload.setup(element);

    const claimUploadTarget = () => {
      this.args.uppyComposerUpload.textManipulation = textManipulation;
    };
    textManipulation.textarea.addEventListener("focusin", claimUploadTarget);

    return () => {
      textManipulation.textarea.removeEventListener(
        "focusin",
        claimUploadTarget
      );
      this.args.uppyComposerUpload.teardown(element);
    };
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
