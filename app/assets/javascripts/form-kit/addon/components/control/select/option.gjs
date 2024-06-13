import { eq } from "truth-helpers";

const FKControlSelectOption = <template>
  {{! https://github.com/emberjs/ember.js/issues/19115 }}
  {{#if (eq @selected @value)}}
    <option
      class="form-kit__control-select__option"
      value={{@value}}
      selected
      ...attributes
    >
      {{yield}}
    </option>
  {{else}}
    <option
      class="form-kit__control-select__option"
      value={{@value}}
      ...attributes
    >
      {{yield}}
    </option>
  {{/if}}
</template>;

export default FKControlSelectOption;
