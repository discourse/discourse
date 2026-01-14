import { htmlSafe } from "@ember/template";
import DEditor from "discourse/components/d-editor";
import icon from "discourse/helpers/d-icon";

const FormTemplateFieldComposer = <template>
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

    <DEditor
      name={{@id}}
      class="form-template-field__composer"
      @value={{@value}}
      @change={{this.handleInput}}
      @placeholder={{@attributes.placeholder}}
    />
  </div>
</template>;

export default FormTemplateFieldComposer;
