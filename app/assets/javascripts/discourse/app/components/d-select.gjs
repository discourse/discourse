import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { isNone } from "@ember/utils";
import { eq } from "truth-helpers";
import { i18n } from "discourse-i18n";

export const NO_VALUE_OPTION = "__NONE__";

export class DSelectOption extends Component {
  get value() {
    return isNone(this.args.value) ? NO_VALUE_OPTION : this.args.value;
  }

  <template>
    {{! https://github.com/emberjs/ember.js/issues/19115 }}
    {{#if (eq @selected @value)}}
      <option
        class="d-select__option --selected"
        value={{this.value}}
        selected
        ...attributes
      >
        {{yield}}
      </option>
    {{else}}
      <option class="d-select__option" value={{this.value}} ...attributes>
        {{yield}}
      </option>
    {{/if}}
  </template>
}

export default class DSelect extends Component {
  @action
  handleInput(event) {
    // if an option has no value, event.target.value will be the content of the option
    // this is why we use this magic value to represent no value
    this.args.onChange(
      event.target.value === NO_VALUE_OPTION ? undefined : event.target.value
    );
  }

  get hasSelectedValue() {
    return this.args.value && this.args.value !== NO_VALUE_OPTION;
  }

  get includeNone() {
    return this.args.includeNone ?? true;
  }

  <template>
    <select
      value={{@value}}
      ...attributes
      class="d-select"
      {{on "input" this.handleInput}}
    >
      {{#if this.includeNone}}
        <DSelectOption @value={{NO_VALUE_OPTION}}>
          {{#if this.hasSelectedValue}}
            {{i18n "none_placeholder"}}
          {{else}}
            {{i18n "select_placeholder"}}
          {{/if}}
        </DSelectOption>
      {{/if}}

      {{yield (hash Option=(component DSelectOption selected=@value))}}
    </select>
  </template>
}
