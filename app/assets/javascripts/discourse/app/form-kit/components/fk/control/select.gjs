import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { NO_VALUE_OPTION } from "discourse/form-kit/lib/constants";
import { i18n } from "discourse-i18n";
import FKControlSelectOption from "./select/option";

export default class FKControlSelect extends Component {
  static controlType = "select";

  @action
  handleInput(event) {
    // if an option has no value, event.target.value will be the content of the option
    // this is why we use this magic value to represent no value
    this.args.field.set(
      event.target.value === NO_VALUE_OPTION ? undefined : event.target.value
    );
  }

  get hasSelectedValue() {
    return this.args.field.value && this.args.field.value !== NO_VALUE_OPTION;
  }

  <template>
    <select
      value={{@field.value}}
      disabled={{@field.disabled}}
      ...attributes
      class="form-kit__control-select"
      {{on "input" this.handleInput}}
    >
      <FKControlSelectOption @value={{NO_VALUE_OPTION}}>
        {{#if this.hasSelectedValue}}
          {{i18n "form_kit.select.unselect_placeholder"}}
        {{else}}
          {{i18n "form_kit.select.select_placeholder"}}
        {{/if}}
      </FKControlSelectOption>

      {{yield
        (hash Option=(component FKControlSelectOption selected=@field.value))
      }}
    </select>
  </template>
}
