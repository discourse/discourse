import { Input } from "@ember/component";
import icon from "discourse/helpers/d-icon";
import htmlSafe from "discourse/helpers/html-safe";
const Checkbox = <template><div class="control-group form-template-field" data-field-type="checkbox">
  <label class="form-template-field__label">
    <Input name={{@id}} class="form-template-field__checkbox" @checked={{@value}} @type="checkbox" required={{if @validations.required "required" ""}} />
    {{@attributes.label}}
    {{#if @validations.required}}
      {{icon "asterisk" class="form-template-field__required-indicator"}}
    {{/if}}
  </label>

  {{#if @attributes.description}}
    <span class="form-template-field__description">
      {{htmlSafe @attributes.description}}
    </span>
  {{/if}}
</div></template>;
export default Checkbox;