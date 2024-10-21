import Component from "@glimmer/component";
import { isNone } from "@ember/utils";
import { eq } from "truth-helpers";
import { NO_VALUE_OPTION } from "discourse/form-kit/lib/constants";

export default class FKControlSelectOption extends Component {
  get value() {
    return isNone(this.args.value) ? NO_VALUE_OPTION : this.args.value;
  }

  <template>
    {{! https://github.com/emberjs/ember.js/issues/19115 }}
    {{#if (eq @selected @value)}}
      <option
        class="form-kit__control-option --selected"
        value={{this.value}}
        selected
        ...attributes
      >
        {{yield}}
      </option>
    {{else}}
      <option
        class="form-kit__control-option"
        value={{this.value}}
        ...attributes
      >
        {{yield}}
      </option>
    {{/if}}
  </template>
}
