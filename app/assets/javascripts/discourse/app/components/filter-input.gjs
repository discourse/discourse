import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { modifier } from "ember-modifier";
import concatClass from "discourse/helpers/concat-class";
import noop from "discourse/helpers/noop";
import icon from "discourse-common/helpers/d-icon";

export default class FilterInput extends Component {
  @tracked isFocused = false;

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

  <template>
    <div
      class={{concatClass
        @containerClass
        "filter-input-container"
        (if this.isFocused "is-focused")
      }}
    >
      {{#if @icons.left}}
        {{icon @icons.left class="-left"}}
      {{/if}}

      <Input
        {{this.focusState}}
        {{on "input" (if @filterAction @filterAction (noop))}}
        @value={{@value}}
        class="filter-input"
        ...attributes
      />

      {{yield}}

      {{#if @icons.right}}
        {{icon @icons.right class="-right"}}
      {{/if}}
    </div>
  </template>
}
