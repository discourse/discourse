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

export default class DFilterInput extends Component {
  @tracked isFocused = false;

  registerInput = modifier((element) => {
    this.input = element;
  });

  focusState = modifier((element) => {
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

  @action
  onClearInput(event) {
    this.args.onClearInput(event);
    this.input?.focus();
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
          class="btn-small btn-transparent filter-input-clear-btn"
        />
      {{/if}}

      {{#if @icons.right}}
        {{dIcon @icons.right class="-right"}}
      {{/if}}
    </div>
  </template>
}
