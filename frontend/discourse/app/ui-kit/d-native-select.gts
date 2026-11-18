import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { isNone } from "@ember/utils";
import type { WithBoundArgs } from "@glint/template";
import { modifier } from "ember-modifier";
import { i18n } from "discourse-i18n";

export const NO_VALUE_OPTION = "__NONE__";

/** The value of an option or a selection: a string, a number, or none. */
export type DNativeSelectValue = string | number | null | undefined;

function optionValue(value: DNativeSelectValue) {
  return isNone(value) ? NO_VALUE_OPTION : String(value);
}

const claimSelectedAfterRender = modifier<{
  Element: HTMLOptionElement;
  Args: { Positional: [selected: boolean] };
}>((element, [selected]) => {
  if (selected) {
    element.selected = true;
  }
});

interface DNativeSelectOptionSignature {
  Args: {
    /** The value of the option. A missing value stands for no value. */
    value?: DNativeSelectValue;

    /** The selected value. The option is selected when its value matches it. */
    selected?: DNativeSelectValue;
  };

  Element: HTMLOptionElement;

  Blocks: {
    /** The option label. */
    default: [];
  };
}

interface DNativeSelectSignature {
  Args: {
    /** The selected value. */
    value?: DNativeSelectValue;

    /** Called with the selected value, or `null` for the no-value option. */
    onChange: (value: string | null) => void;

    /** Whether to offer a no-value option first. Defaults to `true`. */
    includeNone?: boolean;

    /** The label of the no-value option. */
    nonePlaceholder?: string;
  };

  Element: HTMLSelectElement;

  Blocks: {
    default: [
      /** The components to render the options with. */
      select: {
        /** An option, already told which value is selected. */
        Option: WithBoundArgs<typeof DNativeSelectOption, "selected">;
      },
    ];
  };
}

export class DNativeSelectOption extends Component<DNativeSelectOptionSignature> {
  get value() {
    return optionValue(this.args.value);
  }

  get isSelected() {
    return optionValue(this.args.selected) === this.value;
  }

  <template>
    {{! https://github.com/emberjs/ember.js/issues/19115 }}
    <option
      class={{if
        this.isSelected
        "d-native-select__option --selected"
        "d-native-select__option"
      }}
      selected={{this.isSelected}}
      value={{this.value}}
      ...attributes
      {{claimSelectedAfterRender this.isSelected}}
    >
      {{yield}}
    </option>
  </template>
}

export default class DNativeSelect extends Component<DNativeSelectSignature> {
  get htmlSelectValue() {
    const value = this.args.value;
    if (value === NO_VALUE_OPTION) {
      return NO_VALUE_OPTION;
    }
    if (isNone(value) || value === "") {
      return NO_VALUE_OPTION;
    }
    return value;
  }

  get hasSelectedValue() {
    return this.htmlSelectValue !== NO_VALUE_OPTION;
  }

  get includeNone() {
    return this.args.includeNone ?? true;
  }

  @action
  handleInput(event: Event) {
    // if an option has no value, event.target.value will be the content of the option
    // this is why we use this magic value to represent no value
    this.args.onChange(
      (event.target as HTMLSelectElement).value === NO_VALUE_OPTION
        ? null
        : (event.target as HTMLSelectElement).value
    );
  }

  <template>
    <select
      value={{this.htmlSelectValue}}
      ...attributes
      class="d-native-select"
      {{on "input" this.handleInput}}
    >
      {{#if this.includeNone}}
        <DNativeSelectOption
          @selected={{this.htmlSelectValue}}
          @value={{NO_VALUE_OPTION}}
        >
          {{#if @nonePlaceholder}}
            {{@nonePlaceholder}}
          {{else}}
            {{#if this.hasSelectedValue}}
              {{i18n "none_placeholder"}}
            {{else}}
              {{i18n "select_placeholder"}}
            {{/if}}
          {{/if}}
        </DNativeSelectOption>
      {{/if}}

      {{yield
        (hash
          Option=(component DNativeSelectOption selected=this.htmlSelectValue)
        )
      }}
    </select>
  </template>
}
