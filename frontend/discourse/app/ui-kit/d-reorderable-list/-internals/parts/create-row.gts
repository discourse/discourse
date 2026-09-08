import Component from "@glimmer/component";
import type { TemplateOnlyComponent } from "@ember/component/template-only";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import type { ModifierLike } from "@glint/template";
import { modifier } from "ember-modifier";
import DButton from "discourse/ui-kit/d-button";
import { TABLE_CREATE_COLSPAN } from "discourse/ui-kit/d-reorderable-list/-internals/constants";
import dElement from "discourse/ui-kit/helpers/d-element";
import { i18n } from "discourse-i18n";

interface CreateRowSignature {
  Args: {
    itemTag: string;
    onCreate?: (value: string) => void;
  };
}

interface CreateControlsSignature {
  Args: {
    captureInput: ModifierLike<{ Element: HTMLInputElement }>;
    onKeydown: (event: KeyboardEvent) => void;
    submit: () => void;
  };
}

const CreateControls: TemplateOnlyComponent<CreateControlsSignature> =
  <template>
    <input
      {{@captureInput}}
      {{on "keydown" @onKeydown}}
      type="text"
      class="d-reorderable-list__create-input"
      aria-label={{i18n "reorder.add_item"}}
    />
    <DButton
      @icon="plus"
      @action={{@submit}}
      @translatedAriaLabel={{i18n "reorder.add_item"}}
      @translatedTitle={{i18n "reorder.add_item"}}
      class="btn-flat d-reorderable-list__create-button"
    />
  </template>;

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

  get isTableRow(): boolean {
    return this.args.itemTag === "tr";
  }

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
        {{#if this.isTableRow}}
          <td colspan={{TABLE_CREATE_COLSPAN}}>
            <CreateControls
              @captureInput={{this.captureInput}}
              @onKeydown={{this.onKeydown}}
              @submit={{this.submit}}
            />
          </td>
        {{else}}
          <CreateControls
            @captureInput={{this.captureInput}}
            @onKeydown={{this.onKeydown}}
            @submit={{this.submit}}
          />
        {{/if}}
      </Wrapper>
    {{/let}}
  </template>
}
