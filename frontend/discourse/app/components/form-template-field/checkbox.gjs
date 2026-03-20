import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { trustHTML } from "@ember/template";
import dIcon from "discourse/ui-kit/helpers/d-icon";

const Checkbox = <template>
  <div class="control-group form-template-field" data-field-type="checkbox">
    <label class="form-template-field__label">
      <Input
        name={{@id}}
        class="form-template-field__checkbox"
        @checked={{@value}}
        @type="checkbox"
        required={{if @validations.required "required" ""}}
        {{on "input" @onChange}}
      />
      {{@attributes.label}}
      {{#if @validations.required}}
        {{dIcon "asterisk" class="form-template-field__required-indicator"}}
      {{/if}}
    </label>

    {{#if @attributes.description}}
      <span class="form-template-field__description">
        {{trustHTML @attributes.description}}
      </span>
    {{/if}}
  </div>
</template>;

export default Checkbox;
