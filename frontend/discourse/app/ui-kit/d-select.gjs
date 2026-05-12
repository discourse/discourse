// @ts-check
import Component from "@glimmer/component";
import { assert } from "@ember/debug";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { isNone } from "@ember/utils";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

/**
 * Sentinel value used to represent the "no selection" placeholder option. The
 * underlying `<select>` element only deals in strings, so we cannot use a real
 * `undefined`/`null` here; instead the component swaps this sentinel in and
 * out at the boundary so consumers always see a clean `undefined` for "no
 * selection."
 */
export const NO_VALUE_OPTION = "__NONE__";

/**
 * @typedef DSelectOptionSignature
 *
 * @property {object} Args
 *
 * @property {string} [Args.value] Value of this option. Passed back through `@onChange` when selected. When omitted, the option uses the `NO_VALUE_OPTION` sentinel.
 * @property {string} [Args.selected] Currently-selected value at the parent level; the option compares its own `@value` against this to decide whether to mark itself selected. Wired up automatically when used as `<s.Option>` inside a `<DSelect>` yield.
 *
 * @property {HTMLOptionElement} Element
 *
 * @property {object} Blocks
 * @property {[]} Blocks.default The option's visible label.
 */

/**
 * Single `<option>` inside a `DSelect`. Usually rendered via the yielded
 * `s.Option` component rather than imported directly, so the `selected` arg
 * is wired up for you.
 *
 * @extends {Component<DSelectOptionSignature>}
 */
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

/**
 * A controlled native `<select>` wrapper. Consumers render each option via
 * the yielded `s.Option` component so the option's `selected` state is wired
 * up automatically.
 *
 * The component normalizes the "no selection" boundary: internally a special
 * sentinel string is used because `<select>` cannot represent `undefined`,
 * but `@onChange` always receives `undefined` for that case. Pass
 * `@includeNone={{false}}` to drop the placeholder option for required
 * fields.
 *
 * @example
 * <DSelect @value={{this.color}} @onChange={{this.updateColor}} as |s|>
 *   <s.Option @value="red">Red</s.Option>
 *   <s.Option @value="blue">Blue</s.Option>
 * </DSelect>
 */

/**
 * @typedef DSelectSignature
 *
 * @property {object} Args
 *
 * @property {string} [Args.value] Currently-selected option value. Pass `undefined` for "no selection."
 * @property {(value: string | undefined) => void} [Args.onChange] Invoked with the new value on every change. Receives `undefined` when the user picks the placeholder.
 * @property {boolean} [Args.includeNone] Whether to render the placeholder option at the top of the list. Defaults to `true`. Pass `false` for required fields.
 * @property {string} [Args.nonePlaceholder] Custom label for the placeholder option. Defaults to the i18n string `select_placeholder` (or `none_placeholder` once a real value has been selected).
 *
 * @property {HTMLSelectElement} Element
 *
 * @property {object} Blocks
 * @property {[{Option: unknown}]} Blocks.default Yields a hash whose `Option` is `DSelectOption` pre-bound to the current selection so consumers can write `<s.Option @value="x">Label</s.Option>`. Typed as `unknown` because Glint sees the curried form rather than the original class.
 */

/** @extends {Component<DSelectSignature>} */
export default class DSelect extends Component {
  constructor(owner, args) {
    super(owner, args);

    assert(
      "[d-select] @onChange must be a function when provided",
      !this.args.onChange || typeof this.args.onChange === "function"
    );
  }

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

  @action
  handleInput(event) {
    // When an option has no value attribute, event.target.value falls back to
    // the option's text content. We use the NO_VALUE_OPTION sentinel as the
    // value of the placeholder so we can detect "no selection" reliably.
    this.args.onChange?.(
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
      value={{this.htmlSelectValue}}
      ...attributes
      class="d-select"
      {{on "input" this.handleInput}}
    >
      {{#if this.includeNone}}
        <DSelectOption @value={{NO_VALUE_OPTION}}>
          {{#if @nonePlaceholder}}
            {{@nonePlaceholder}}
          {{else}}
            {{#if this.hasSelectedValue}}
              {{i18n "none_placeholder"}}
            {{else}}
              {{i18n "select_placeholder"}}
            {{/if}}
          {{/if}}
        </DSelectOption>
      {{/if}}

      {{yield
        (hash Option=(component DSelectOption selected=this.htmlSelectValue))
      }}
    </select>
  </template>
}
