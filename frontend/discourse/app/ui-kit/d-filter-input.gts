import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { modifier } from "ember-modifier";
import noop from "discourse/helpers/noop";
import { and } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

interface DFilterInputSignature {
  Args: {
    value?: string;
    filterAction?: (event: Event) => void;
    onClearInput?: (event: Event) => void;
    icons?: {
      left?: string;
      right?: string;
    };
    containerClass?: string;
  };

  Element: HTMLInputElement;

  Blocks: {
    default: [];
  };
}

export default class DFilterInput extends Component<DFilterInputSignature> {
  @tracked isFocused = false;

  registerInput = modifier((element: HTMLInputElement) => {
    this.#input = element;
  });

  focusState = modifier((element: HTMLInputElement) => {
    const focusInHandler = () => {
      this.isFocused = true;
    };
    const focusOutHandler = () => {
      this.isFocused = false;
    };

    element.addEventListener("focusin", focusInHandler);
    element.addEventListener("focusout", focusOutHandler);

    return () => {
      element.removeEventListener("focusin", focusInHandler);
      element.removeEventListener("focusout", focusOutHandler);
    };
  });

  #input?: HTMLInputElement;

  @action
  onClearInput(event: Event) {
    this.args.onClearInput?.(event);
    this.#input?.focus();
  }

  <template>
    <div
      class={{dConcatClass
        @containerClass
        "filter-input-container"
        (if this.isFocused "is-focused")
      }}
    >
      {{#if @icons.left}}
        {{dIcon @icons.left class="-left"}}
      {{/if}}

      <input
        {{this.registerInput}}
        {{this.focusState}}
        {{on "input" (if @filterAction @filterAction (noop))}}
        type="text"
        value={{@value}}
        class="filter-input"
        ...attributes
      />

      {{yield}}

      {{#if (and @onClearInput @value.length)}}
        <DButton
          @icon="xmark"
          @action={{this.onClearInput}}
          @title={{i18n "filter_input.clear"}}
          aria-label={{i18n "filter_input.clear"}}
          class="btn-small btn-transparent filter-input-clear-btn"
        />
      {{/if}}

      {{#if @icons.right}}
        {{dIcon @icons.right class="-right"}}
      {{/if}}
    </div>
  </template>
}
