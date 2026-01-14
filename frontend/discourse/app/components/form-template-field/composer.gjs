import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { htmlSafe } from "@ember/template";
import DEditor from "discourse/components/d-editor";
import icon from "discourse/helpers/d-icon";

export default class FormTemplateFieldComposer extends Component {
  @tracked composerValue = this.args.value || "";

  @action
  handleInput(event) {
    this.composerValue = event.target.value;
    next(this, () => {
      this.args.onChange?.(event);
    });
  }

  <template>
    <div class="control-group form-template-field" data-field-type="input">
      {{#if @attributes.label}}
        <label class="form-template-field__label">
          {{@attributes.label}}
          {{#if @validations.required}}
            {{icon "asterisk" class="form-template-field__required-indicator"}}
          {{/if}}
        </label>
      {{/if}}

      {{#if @attributes.description}}
        <span class="form-template-field__description">
          {{htmlSafe @attributes.description}}
        </span>
      {{/if}}

      <input type="hidden" name={{@id}} value={{this.composerValue}} />

      <DEditor
        class="form-template-field__composer"
        @value={{this.composerValue}}
        @change={{this.handleInput}}
        @placeholder={{@attributes.placeholder}}
      />
    </div>
  </template>
}
