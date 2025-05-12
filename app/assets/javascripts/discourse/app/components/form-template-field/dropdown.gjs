import { on } from "@ember/modifier";
import { htmlSafe } from "@ember/template";
import { eq } from "truth-helpers";
import icon from "discourse/helpers/d-icon";

const Dropdown = <template>
  <div class="control-group form-template-field" data-field-type="dropdown">
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

    <select
      name={{@id}}
      class="form-template-field__dropdown"
      required={{if @validations.required "required" ""}}
      {{on "input" @onChange}}
    >
      {{#if @attributes.none_label}}
        <option
          class="form-template-field__dropdown-placeholder"
          value
          disabled
          selected
          hidden
        >{{@attributes.none_label}}</option>
      {{/if}}
      {{#each @choices as |choice|}}
        <option
          value={{choice}}
          selected={{eq @value choice}}
        >{{choice}}</option>
      {{/each}}
    </select>
  </div>
</template>;

export default Dropdown;
