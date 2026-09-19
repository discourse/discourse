import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { trustHTML } from "@ember/template";
import dIcon from "discourse/ui-kit/helpers/d-icon";

const FormTemplateFieldInput = <template>
  <div class="control-group form-template-field" data-field-type="input">
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

    <Input
      class="form-template-field__input"
      disabled={{@attributes.disabled}}
      maxlength={{@validations.maximum}}
      minlength={{@validations.minimum}}
      name={{@id}}
      pattern={{@validations.pattern}}
      placeholder={{@attributes.placeholder}}
      required={{if @validations.required "required" ""}}
      @type={{if @validations.type @validations.type "text"}}
      @value={{@value}}
      {{on "input" @onChange}}
    />
  </div>
</template>;

export default FormTemplateFieldInput;
