import Component from "@glimmer/component";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import icon from "discourse-common/helpers/d-icon";

export default class FormTemplateFieldMultiSelect extends Component {
  @action
  isSelected(option) {
    return this.args.value?.includes(option);
  }

  <template>
    <div
      data-field-type="multi-select"
      class="control-group form-template-field"
    >
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
        required={{if @validations.required "required" ""}}
        multiple="multiple"
        class="form-template-field__multi-select"
      >
        {{#if @attributes.none_label}}
          <option
            class="form-template-field__multi-select-placeholder"
            value=""
            disabled
            hidden
          >{{@attributes.none_label}}</option>
        {{/if}}
        {{#each @choices as |choice|}}
          <option
            value={{choice}}
            selected={{this.isSelected choice}}
          >{{choice}}</option>
        {{/each}}
      </select>
    </div>
  </template>
}
