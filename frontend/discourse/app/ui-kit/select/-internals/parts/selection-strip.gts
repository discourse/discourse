import Component from "@glimmer/component";
import { concat, fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { makeArray } from "discourse/lib/helpers";
import type { CapabilitiesService } from "discourse/services/capabilities";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DSkeleton from "discourse/ui-kit/d-skeleton";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dOnResize from "discourse/ui-kit/modifiers/d-on-resize";
import dRovingFocus, {
  type DRovingFocusApi,
} from "discourse/ui-kit/modifiers/d-roving-focus";
import SelectionLabel from "discourse/ui-kit/select/-internals/parts/selection-label";
import SelectEngine, {
  SelectDescriptor,
  SelectItem,
  SelectLoadOptions,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";

interface SelectionStripSignature {
  Args: {
    /** The headless selection engine. */
    engine: SelectEngine;
    /** The current controlled selection, in held order. */
    value?: SelectValue;
    /** Resolves labels through the same cache as the trigger. */
    resolveSelection: (
      value: unknown,
      options?: SelectLoadOptions
    ) =>
      | readonly SelectDescriptor[]
      | Promise<readonly SelectDescriptor[] | undefined>
      | undefined;
    /** Whether mutation is disabled. */
    locked: boolean;
    /** Whether the consumer supplies selected-item markup. */
    hasSelectionBlock: boolean;
    /** Whether the consumer supplies unresolved-item markup. */
    hasUnresolvedBlock: boolean;
    /** Registers this strip's independent roving group. */
    onRegisterRoving: (api: DRovingFocusApi | null) => void;
    /** Focuses a remaining chip by index. */
    focusStrip: (index: number) => boolean;
    /** Focuses the query or list when no chip remains. */
    focusFallback: () => void;
    /** Returns desktop typeahead navigation from the strip to its query input. */
    returnToInput?: () => void;
    /** Remeasures the results when the strip's height changes. */
    onResize: () => void;
  };
  Blocks: {
    /** Consumer markup for a resolved held item. */
    selection?: [/** The held item. */ item: SelectItem];
    /** Consumer markup for an unavailable held item. */
    unresolved?: [/** The fallback item. */ item: SelectItem];
  };
}

/** Removable held items in an overlay, with its own scroll and roving focus. */
export default class SelectionStrip extends Component<SelectionStripSignature> {
  @service declare capabilities: CapabilitiesService;

  /** Stable prefix for label and removal-hint associations. */
  get idPrefix(): string {
    return `d-select-strip-${guidFor(this)}`;
  }

  /** One inert placeholder per held value while labels resolve. */
  get skeletons(): number[] {
    return makeArray(this.args.value).map((_, index) => index);
  }

  /** Preserves query focus on pointer presses, including synthesized mouse events. */
  @action
  preventPointerBlur(event: Event): void {
    event.preventDefault();
  }

  /** Handles removal keys before the roving group's activation handler. */
  @action
  handleKeydown(item: SelectItem, index: number, event: KeyboardEvent): void {
    if (event.isComposing) {
      return;
    }
    if (
      this.args.returnToInput &&
      (event.key === "ArrowUp" ||
        event.key === "ArrowDown" ||
        (event.key === "Tab" && event.shiftKey))
    ) {
      event.preventDefault();
      event.stopPropagation();
      this.args.returnToInput();
      return;
    }
    if (["Enter", " ", "Backspace", "Delete"].includes(event.key)) {
      event.preventDefault();
      event.stopPropagation();
      this.#remove(item, index, true);
    }
  }

  /** Pointer activation preserves focus; assistive activation restores a neighbor. */
  @action
  removeItem(item: SelectItem, index: number, event: MouseEvent): void {
    event.stopPropagation();
    this.#remove(item, index, document.activeElement === event.currentTarget);
  }

  /** Converts a held item's id to its attribute value. */
  chipValue(chip: SelectDescriptor): string {
    return String(chip.value ?? "");
  }

  #remove(item: SelectItem, index: number, restoreFocus: boolean): void {
    if (this.args.locked) {
      return;
    }
    // Move before the final chip unmounts, so focus never falls through to body.
    const isLast = makeArray(this.args.value).length === 1;
    if (isLast && restoreFocus) {
      this.args.focusFallback();
    }
    this.args.engine.deselect(item);
    if (restoreFocus && !isLast) {
      next(() => {
        if (
          !this.isDestroying &&
          !this.args.focusStrip(Math.max(0, index - 1))
        ) {
          this.args.focusFallback();
        }
      });
    }
  }

  <template>
    <DAsyncContent @asyncData={{@resolveSelection}} @context={{@value}}>
      <:loading>
        <ul
          aria-label={{@engine.text "stripLabel"}}
          class="d-select__strip"
          tabindex="-1"
          {{dOnResize @onResize}}
          {{didInsert @onResize}}
          {{willDestroy @onResize}}
        >
          {{#each this.skeletons as |index|}}
            <li class="d-select__strip-item" data-key={{index}}>
              <DSkeleton @variant="text" @width="6ch" />
            </li>
          {{/each}}
        </ul>
      </:loading>
      <:content as |chips|>
        <ul
          aria-label={{@engine.text "stripLabel"}}
          class="d-select__strip"
          tabindex="-1"
          {{dOnResize @onResize}}
          {{didInsert @onResize}}
          {{willDestroy @onResize}}
          {{dRovingFocus
            itemSelector=".d-select__strip-remove"
            itemsKey=chips
            orientation="horizontal"
            restoreLostFocus=false
            onRegisterApi=@onRegisterRoving
          }}
        >
          {{#each chips key="key" as |chip index|}}
            <li
              class="d-select__strip-item"
              data-name={{@engine.getSelectionLabel chip.item}}
              data-value={{this.chipValue chip}}
            >
              <button
                aria-label={{if
                  this.capabilities.touch
                  (@engine.text
                    "removeItem"
                    (hash item=(@engine.getSelectionLabel chip.item))
                  )
                }}
                aria-labelledby={{unless
                  this.capabilities.touch
                  (concat
                    this.idPrefix
                    "-"
                    index
                    "-label "
                    this.idPrefix
                    "-"
                    index
                    "-hint"
                  )
                }}
                class="d-select__strip-remove"
                disabled={{@locked}}
                tabindex="-1"
                type="button"
                {{! eslint-disable-next-line ember/template-no-pointer-down-event-binding }}
                {{on "pointerdown" this.preventPointerBlur}}
                {{! eslint-disable-next-line ember/template-no-pointer-down-event-binding }}
                {{on "mousedown" this.preventPointerBlur}}
                {{on "click" (fn this.removeItem chip.item index)}}
                {{on "keydown" (fn this.handleKeydown chip.item index)}}
              >
                <span
                  aria-hidden="true"
                  class="d-select__strip-label"
                  id="{{this.idPrefix}}-{{index}}-label"
                >
                  {{#if chip.item.__unresolved}}
                    {{#if @hasUnresolvedBlock}}
                      {{yield chip.item to="unresolved"}}
                    {{else}}
                      <SelectionLabel @engine={{@engine}} @item={{chip.item}} />
                    {{/if}}
                  {{else if @hasSelectionBlock}}
                    {{yield chip.item to="selection"}}
                  {{else}}
                    <SelectionLabel @engine={{@engine}} @item={{chip.item}} />
                  {{/if}}
                </span>
                <span class="sr-only" id="{{this.idPrefix}}-{{index}}-hint">
                  {{~@engine.text "removeHint"~}}
                </span>
                {{dIcon "xmark"}}
              </button>
            </li>
          {{/each}}
        </ul>
      </:content>
    </DAsyncContent>
  </template>
}
