import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { modifier } from "ember-modifier";
import DButton from "discourse/ui-kit/d-button";
import dElement from "discourse/ui-kit/helpers/d-element";
import { i18n } from "discourse-i18n";

interface CreateRowSignature {
  Args: {
    itemTag: string;
    onCreate?: (value: string) => void;
  };
}

/**
 * The default create affordance: a text input and an add button rendered as
 * one extra row. Submitting via Enter or the button reports the trimmed value
 * and clears the input; an empty or whitespace-only value reports nothing.
 */
export default class CreateRow extends Component<CreateRowSignature> {
  captureInput = modifier((element: HTMLInputElement) => {
    this.#input = element;
    return () => (this.#input = undefined);
  });
  /**
   * The live input element. Read directly at submit time instead of mirroring
   * keystrokes into tracked state: the value only matters at that moment, and
   * clearing must reach the element's property — resetting a bound attribute
   * would not clear what the user typed.
   */
  #input?: HTMLInputElement;

  @action
  onKeydown(event: KeyboardEvent) {
    // A keydown arriving mid-IME-composition belongs to the candidate window,
    // not to this control.
    if (event.key === "Enter" && !event.isComposing) {
      event.preventDefault();
      this.#submit();
    }
  }

  @action
  submit() {
    this.#submit();
  }

  #submit() {
    const element = this.#input;
    const value = element?.value.trim();
    // Without a handler the value has nowhere to go, so it stays in the input
    // instead of being silently discarded.
    if (!element || !value || !this.args.onCreate) {
      return;
    }
    this.args.onCreate(value);
    element.value = "";
  }

  <template>
    {{#let (dElement @itemTag) as |Wrapper|}}
      <Wrapper class="d-reorderable-list__create">
        <input
          {{this.captureInput}}
          {{on "keydown" this.onKeydown}}
          type="text"
          class="d-reorderable-list__create-input"
          aria-label={{i18n "reorder.add_item"}}
        />
        <DButton
          @icon="plus"
          @action={{this.submit}}
          @translatedAriaLabel={{i18n "reorder.add_item"}}
          @translatedTitle={{i18n "reorder.add_item"}}
          class="btn-flat d-reorderable-list__create-button"
        />
      </Wrapper>
    {{/let}}
  </template>
}
