import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import { next as nextRunloop } from "@ember/runloop";
import booleanString from "discourse/helpers/boolean-string";
import { makeArray } from "discourse/lib/helpers";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DSkeleton from "discourse/ui-kit/d-skeleton";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dRovingFocus, {
  type DRovingFocusApi,
} from "discourse/ui-kit/modifiers/d-roving-focus";
import type VariantPresenter from "discourse/ui-kit/select/-internals/coordinators/variant-presenter";
import keepAboveKeyboard from "discourse/ui-kit/select/-internals/modifiers/keep-above-keyboard";
import ComboboxQueryInput from "discourse/ui-kit/select/-internals/parts/combobox-query-input";
import SelectionLabel from "discourse/ui-kit/select/-internals/parts/selection-label";
import SelectEngine, {
  SelectDescriptor,
  SelectItem,
  SelectLoadOptions,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

interface MultiChipsSignature {
  Args: {
    /** The current bound selection. */
    value?: SelectValue;
    /** The headless selection engine. */
    engine: SelectEngine;
    /** The stable helper for variant-specific presentation state. */
    presenter: VariantPresenter;
    /** The id of the currently rendered listbox. */
    listboxId?: string;
    /** Whether the menu is expanded. */
    expanded: boolean;
    /** Whether query editing has begun. */
    editing: boolean;
    /** The combobox element id. */
    id?: string;
    /** Whether the combobox is invalid. */
    invalid?: boolean;
    /** External description ids for the combobox. */
    describedBy?: string;
    /** Whether the consumer supplied custom selection markup. */
    hasSelectionBlock: boolean;
    /** Resolves the bound selection into chip descriptors. */
    resolveSelection: (
      value: unknown,
      options?: SelectLoadOptions
    ) =>
      | readonly SelectDescriptor[]
      | Promise<readonly SelectDescriptor[]>
      | undefined;
    /** Composes the component and consumer description ids. */
    composeDescribedBy: (
      ...ids: Array<string | undefined | false>
    ) => string | undefined;
    /** Opens the menu. */
    showMenu: () => void;
    /** Closes the menu. */
    closeMenu: () => void;
    /** Focuses the query input. */
    focusInput: () => void;
    /** Moves focus to a chip by index. */
    focusChip: (index: number) => boolean;
    /** Reports the chip roving-focus API to the owner. */
    onRegisterChipRoving: (api: DRovingFocusApi | null) => void;
    /** Determines whether focus should select the displayed label. */
    shouldSelectOnFocus: () => boolean;
    /** Handles query editing. */
    onEdit: () => void;
    /** Captures the desktop query input. */
    registerInput: (element: HTMLElement) => void;
    /** Handles focus leaving the desktop query input. */
    onBlur: (event: FocusEvent) => void;
    /** Handles selection-removal keys on the query input. */
    onInputKeydown: (event: KeyboardEvent) => void;
    /** Whether the keyboard-occlusion correction should run. */
    shouldCorrectKeyboardOcclusion: () => boolean;
  };
  Blocks: {
    /** Custom markup for a selected item. */
    selection?: [
      /** The resolved selected item. */
      item: SelectItem,
    ];
  };
}

export default class MultiChips extends Component<MultiChipsSignature> {
  /** Stable prefix for the per-chip element ids (label + remove button). */
  get chipIdPrefix(): string {
    return `d-combobox-chip-${guidFor(this)}`;
  }

  /** Stable id for the query input's `aria-describedby` chip-navigation hint. */
  get chipHintId(): string {
    return `d-combobox-chip-hint-${guidFor(this)}`;
  }

  /**
   * Chip-shaped placeholder rows while the held values resolve — one per bound id, so
   * the loading state matches the number of chips about to appear.
   */
  get chipSkeletons(): Array<{ key: number }> {
    const count = makeArray(this.args.value).length;
    return Array.from({ length: count }, (_, key) => ({ key }));
  }

  /**
   * Returns focus to the query input when the roving cursor steps off the right (input-side)
   * edge of the chip group. At the left edge (`backward`) it stays on the first chip.
   *
   * @param direction - The travel direction that hit the edge.
   */
  @action
  exitChipsToInput(direction: "forward" | "backward"): void {
    if (direction === "forward") {
      this.args.focusInput();
    }
  }

  /**
   * Desktop multi: keyboard handling for a focused chip.
   *
   * - **ArrowDown / ArrowUp** move focus back to the query input and open the overlay — the same
   *   "go to the options" gesture the input itself uses. Focus has to land on the input because
   *   the listbox highlight is driven by `aria-activedescendant` on the input (active mode), not
   *   on the chip; this is also how the control is reopened after Escape.
   * - **Backspace / Delete** remove the chip and keep the cursor in the group, landing on the
   *   previous chip (or the input when the first/last one goes or a loading re-flash leaves no
   *   button to focus).
   * - **Enter / Space** are left to the button's native activation (→ `removeItem`, which returns
   *   focus to the input), so there is a single removal path and no synthesized-click race.
   * - **Escape** is not handled here — float-kit's document-level capture listener closes the
   *   overlay first; focus stays on the chip (still arrow-navigable, reopen with ArrowDown).
   *
   * @param item - The chip's item.
   * @param index - The chip's position, for restoring focus to a neighbor.
   * @param event - The keydown event.
   */
  @action
  handleChipKeydown(
    item: SelectItem,
    index: number,
    event: KeyboardEvent
  ): void {
    if (!this.args.presenter.isDesktopTypeahead) {
      return;
    }

    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault();
      this.args.focusInput();
      if (!this.args.presenter.isLocked) {
        this.args.showMenu();
      }
      return;
    }

    if (this.args.presenter.isLocked) {
      return;
    }

    if (event.key === "Backspace" || event.key === "Delete") {
      event.preventDefault();
      event.stopPropagation();
      this.args.engine.deselect(item);
      // The chip DOM re-renders on the value change; restore focus once it settles. A
      // macrotask lands after the render flush, and the boolean guard falls back to the
      // input if the group is momentarily empty.
      nextRunloop(() => {
        const remaining = makeArray(this.args.value).length;
        if (remaining > 0 && this.args.focusChip(Math.max(0, index - 1))) {
          return;
        }
        this.args.focusInput();
      });
    }
  }

  /**
   * Removes a chip's item, stops the click from opening the menu, and restores input focus
   * after the focused remove button unmounts. Handles a pointer click and the button's
   * native Enter/Space activation; Backspace/Delete go through `handleChipKeydown`.
   */
  @action
  removeItem(item: SelectItem, event?: MouseEvent): void {
    event?.stopPropagation();
    if (this.args.presenter.isLocked) {
      return;
    }
    this.args.engine.deselect(item);
    this.args.focusInput();
  }

  <template>
    {{! Desktop multi: the chips are a horizontal arrow-roving group whose remove buttons
      are the navigable items (tabindex -1 below), so the query input stays the sole tab
      stop. Gated to desktop — the mobile trigger has no inline input to enter the chips
      from. }}
    {{! The chips are a real list (ul/li) so assistive tech announces them as a
      navigable collection; display:contents keeps the items flowing inline with the
      query input, which is a sibling of the list (an input cannot be a child of a ul). }}
    <div class="d-combobox__chips">
      <ul
        class="d-combobox__chip-list"
        aria-label={{i18n "d_select.selected_items"}}
        {{(if
          @presenter.isDesktopTypeahead
          (modifier
            dRovingFocus
            tabStop=false
            orientation="horizontal"
            itemSelector=".d-combobox__chip-remove"
            onExit=this.exitChipsToInput
            onRegisterApi=@onRegisterChipRoving
          )
        )}}
      >
        <DAsyncContent @asyncData={{@resolveSelection}} @context={{@value}}>
          <:loading>
            {{#each this.chipSkeletons key="key" as |row|}}
              <li class="d-combobox__chip" data-key={{row.key}}>
                <DSkeleton @variant="text" @width="6ch" />
              </li>
            {{/each}}
          </:loading>
          <:content as |chips|>
            {{#each chips key="key" as |chip index|}}
              <li class="d-combobox__chip">
                {{! Hidden from assistive tech: the remove button's accessible name
                  already carries this label (via aria-labelledby), so exposing the
                  text again would double every chip during item-by-item navigation. }}
                <span
                  class="d-combobox__chip-label"
                  id="{{this.chipIdPrefix}}-{{index}}-label"
                  aria-hidden="true"
                >
                  {{#if @hasSelectionBlock}}
                    {{yield chip.item to="selection"}}
                  {{else}}
                    <SelectionLabel
                      @item={{chip.item}}
                      @labelField={{@presenter.labelField}}
                    />
                  {{/if}}
                </span>
                <button
                  type="button"
                  class="d-combobox__chip-remove"
                  disabled={{@presenter.isLocked}}
                  {{! Desktop: never a tab stop — reached by arrow-roving from the input.
                    A static -1 keeps every newly-rendered chip out of the tab order with
                    no dependence on the modifier re-seeding. Mobile keeps native tab stops. }}
                  tabindex={{if @presenter.isDesktopTypeahead "-1"}}
                  {{! Name leads with the item, then how to remove it (e.g. "Orange, Press
                    Backspace or Delete to remove") so it reads as a selected item rather
                    than a bare action. }}
                  aria-labelledby="{{this.chipIdPrefix}}-{{index}}-label {{this.chipIdPrefix}}-{{index}}-remove"
                  {{on "click" (fn this.removeItem chip.item)}}
                  {{on "keydown" (fn this.handleChipKeydown chip.item index)}}
                >
                  <span
                    class="sr-only"
                    id="{{this.chipIdPrefix}}-{{index}}-remove"
                  >
                    {{i18n "d_select.remove_hint"}}
                  </span>
                  {{dIcon "xmark"}}
                </button>
              </li>
            {{/each}}
          </:content>
        </DAsyncContent>
      </ul>
      {{#if @presenter.isDesktopTypeahead}}
        <ComboboxQueryInput
          @engine={{@engine}}
          @listboxId={{@listboxId}}
          @expanded={{@expanded}}
          @label={{@presenter.ariaLabelText}}
          @displayValue=""
          @placeholder={{@presenter.queryPlaceholder}}
          @editing={{@editing}}
          @ariaOwns={{true}}
          @shouldSelectOnFocus={{@shouldSelectOnFocus}}
          @onOpen={{@showMenu}}
          @onRequestClose={{@closeMenu}}
          @onBlur={{@onBlur}}
          @onEdit={{@onEdit}}
          @registerInput={{@registerInput}}
          @disabled={{@presenter.isDisabled}}
          @readonly={{@presenter.isReadonly}}
          id={{@id}}
          aria-invalid={{booleanString @invalid}}
          aria-describedby={{@composeDescribedBy
            (if @engine.hasValue this.chipHintId)
            @describedBy
          }}
          {{keepAboveKeyboard @shouldCorrectKeyboardOcclusion}}
          {{on "keydown" @onInputKeydown}}
        />
        {{#if @engine.hasValue}}
          <span id={{this.chipHintId}} class="sr-only">
            {{i18n "d_select.chips_hint"}}
          </span>
        {{/if}}
      {{/if}}
    </div>
  </template>
}
