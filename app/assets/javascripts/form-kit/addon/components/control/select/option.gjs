import Component from "@glimmer/component";
import { NO_VALUE_OPTION } from "form-kit/lib/constants";
import { eq } from "truth-helpers";

export default class FKControlSelectOption extends Component {
  get value() {
    return typeof this.args.value === "undefined"
      ? NO_VALUE_OPTION
      : this.args.value;
  }

  <template>
    {{! https://github.com/emberjs/ember.js/issues/19115 }}
    {{#if (eq @selected @value)}}
      <option
        class="form-kit__control-select__option"
        value={{this.value}}
        selected
        ...attributes
      >
        {{yield}}
      </option>
    {{else}}
      <option
        class="form-kit__control-select__option"
        value={{this.value}}
        ...attributes
      >
        {{yield}}
      </option>
    {{/if}}
  </template>
}
