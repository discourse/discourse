import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import { cancel, schedule } from "@ember/runloop";
import { service } from "@ember/service";
import type { TrackedAsyncData } from "ember-async-data";
import { modifier as createModifier } from "ember-modifier";
import { makeArray } from "discourse/lib/helpers";
import type { CapabilitiesService } from "discourse/services/capabilities";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DSkeleton from "discourse/ui-kit/d-skeleton";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dOnResize from "discourse/ui-kit/modifiers/d-on-resize";
import dRovingFocus, {
  type DRovingFocusApi,
  type DRovingFocusAxis,
} from "discourse/ui-kit/modifiers/d-roving-focus";
import type VariantPresenter from "discourse/ui-kit/select/-internals/coordinators/variant-presenter";
import keepAboveKeyboard from "discourse/ui-kit/select/-internals/modifiers/keep-above-keyboard";
import ComboboxQueryInput from "discourse/ui-kit/select/-internals/parts/combobox-query-input";
import SelectionLabel from "discourse/ui-kit/select/-internals/parts/selection-label";
import SelectEngine, {
  SelectDescriptor,
  SelectItem,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

interface MultiChipsSignature {
  Args: {
    /** Whether asynchronous selection work is pending. */
    pending: boolean;
    /** The current bound selection. */
    value?: SelectValue;
    /** The headless selection engine. */
    engine: SelectEngine;
    /** The stable helper for variant-specific presentation state. */
    presenter: Pick<
      VariantPresenter,
      "isLocked" | "isDisabled" | "isReadonly"
    > & { maxVisibleChips?: number };
    /** Search-mode fields show every held chip and let Tab reach the panel host. */
    roleMode?: "combobox" | "search";
    /** Remeasures the list when this field wraps or changes height. */
    onResize?: () => void;
    /** Drops virtual list focus when a chip takes DOM focus. */
    onChipFocus?: () => void;
    /** Whether the field contains a query input. */
    fieldRendersInput: boolean;
    /** Whether the chips rove and offer removal. */
    triggerChipsInteractive: boolean;
    /** Whether the input claims the listbox through aria-owns. */
    ariaOwns: boolean;
    /**
     * Whether an expanded overlay that repeats the held items replaces the chips with a count.
     * The chips stay laid out but hidden, so the field keeps its height and the overlay stays put.
     */
    summarizeWhileExpanded?: boolean;
    /** Overrides Escape's close action. Defaults to closeMenu. */
    onEscape?: (event: KeyboardEvent) => void;
    /** Lets Tab bubble to the host. Defaults to false so Tab exits the trigger. */
    tabPassthrough?: boolean;
    /** Defaults to showing the query only while editing; always shows the engine's filter. */
    queryDisplay?: "editing" | "always";
    /** The input's accessible name. */
    label: string;
    /** The field placeholder. */
    placeholder?: string;
    /** A decorative trailing icon, shown only when the field is a search field. */
    searchIcon?: string;
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
    /** Whether the consumer supplied custom markup for a selection that is still resolving. */
    hasSelectionLoadingBlock: boolean;
    /** Whether the consumer supplied custom markup for a held value that cannot be resolved. */
    hasUnresolvedBlock: boolean;
    /** The held values' chip descriptors, resolved once by the host and shared with its description. */
    selection: TrackedAsyncData<readonly SelectDescriptor[] | undefined>;
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
    shouldSelectOnFocus?: () => boolean;
    /** Handles query editing. */
    onEdit?: () => void;
    /** Handles parsed pastes on the query input. */
    onPaste: (event: ClipboardEvent) => void | Promise<void>;
    /** Captures the query input. */
    registerInput: (element: HTMLInputElement) => void;
    /** Handles focus leaving the query input. */
    onBlur?: (event: FocusEvent) => void;
    /** Handles selection-removal keys on the query input. */
    onInputKeydown: (event: KeyboardEvent) => void;
    /** Whether the keyboard-occlusion correction should run. */
    shouldCorrectKeyboardOcclusion?: () => boolean;
  };
  Blocks: {
    /** Custom markup for a selected item. */
    selection?: [
      /** The resolved selected item. */
      item: SelectItem,
    ];
    /** Custom markup shown in place of a selection while it resolves. */
    selectionLoading?: [];
    /** Custom markup for a held value that cannot be resolved. */
    unresolved?: [
      /** The unresolved fallback item. */
      item: SelectItem,
    ];
  };
}

export default class MultiChips extends Component<MultiChipsSignature> {
  @service declare capabilities: CapabilitiesService;

  /**
   * Keeps the focused chip or caret line in view. Its positionals, the held values and their
   * resolved labels, only make it re-run when either changes.
   */
  watchField = createModifier<{
    Element: HTMLElement;
    Args: { Positional: [value: unknown, resolved: unknown] };
  }>((element) => {
    this.#element = element;
    const check = schedule("afterRender", () => {
      if (!this.isDestroying && element.contains(document.activeElement)) {
        this.#revealFocused();
      }
    });
    return () => {
      cancel(check);
    };
  });

  #element: HTMLElement | null = null;

  /** Whether the chips are hidden behind a count while the overlay is open. */
  get summarized(): boolean {
    return Boolean(
      this.args.summarizeWhileExpanded &&
      this.args.expanded &&
      this.args.engine.hasValue
    );
  }

  /** The count shown in place of the chips. */
  get summary(): string {
    const value = this.args.engine.value;
    return i18n("d_select.selected_count", {
      count: Array.isArray(value) ? value.length : 0,
    });
  }

  /** Stable prefix for the per-chip element ids (label + remove button). */
  get chipIdPrefix(): string {
    return `d-select-chip-${guidFor(this)}`;
  }

  /** Stable id for the query input's `aria-describedby` chip-navigation hint. */
  get chipHintId(): string {
    return `d-select-chip-hint-${guidFor(this)}`;
  }

  /**
   * Mirrors held chips, with one placeholder for an update on an empty selection.
   */
  get chipSkeletons(): Array<{ key: number }> {
    const count = Math.max(
      this.args.pending ? 1 : 0,
      makeArray(this.args.value).length
    );
    return Array.from({ length: count }, (_, key) => ({ key }));
  }

  /** The decorative count of held values beyond the visible chips. */
  get moreLabel(): string | undefined {
    const maximum =
      this.args.roleMode === "search"
        ? undefined
        : this.args.presenter.maxVisibleChips;
    const value = this.args.engine.value;
    const count = Array.isArray(value) ? value.length : 0;
    if (maximum === undefined || count <= maximum) {
      return undefined;
    }
    return maximum === 0 ? String(count) : `+${count - maximum}`;
  }

  /** Display-only chips describe the panel instead of advertising trigger-chip removal. */
  get chipHint(): string | undefined {
    if (!this.args.engine.hasValue) {
      return undefined;
    }
    return i18n(
      this.args.triggerChipsInteractive
        ? "d_select.chips_hint"
        : "d_select.selected_items_hint"
    );
  }

  /** Restricts both resolved chips and loading placeholders to the trigger budget. */
  @action
  visibleChips<T>(chips: readonly T[] | undefined): readonly T[] {
    return this.args.roleMode === "search" ||
      this.args.presenter.maxVisibleChips === undefined
      ? (chips ?? [])
      : (chips ?? []).slice(0, this.args.presenter.maxVisibleChips);
  }

  /** Converts a held item's id to its chip attribute value. */
  chipValue(chip: SelectDescriptor): string {
    return String(chip.value ?? "");
  }

  /**
   * Returns focus to the query input when the roving cursor steps off the input-side end of the
   * chip group. At the other end (`backward`) it stays on the first chip.
   *
   * Branches on `axis` because `onBoundary` reports both. This group is horizontal, so a vertical
   * boundary cannot reach it today; handing focus away on one would be wrong rather than merely
   * unreachable, so the guard is stated rather than assumed.
   *
   * @param direction - The travel direction that hit the boundary.
   * @param axis - The axis the cursor was travelling.
   */
  @action
  exitChipsToInput(
    direction: "forward" | "backward",
    axis: DRovingFocusAxis
  ): void {
    if (axis === "horizontal" && direction === "forward") {
      this.args.focusInput();
    }
  }

  /** Keeps removal focus inside the field; native button activation returns to the input. */
  @action
  handleChipKeydown(
    item: SelectItem,
    index: number,
    event: KeyboardEvent
  ): void {
    if (!this.args.fieldRendersInput) {
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

    if (event.key === "Tab") {
      this.args.focusInput();
      return;
    }

    if (this.args.presenter.isLocked || event.isComposing) {
      return;
    }

    if (event.key === "Backspace" || event.key === "Delete") {
      event.preventDefault();
      event.stopPropagation();
      // Focus moves before the removal: the removed button unmounts, and focus it still holds
      // would fall to the page. The neighbour is keyed, so it survives the re-render. Focus the
      // chip does not hold is never claimed.
      if (document.activeElement === event.currentTarget) {
        const neighbour = index > 0 ? index - 1 : 1;
        if (
          makeArray(this.args.value).length === 1 ||
          !this.args.focusChip(neighbour)
        ) {
          this.args.focusInput();
        }
      }
      this.args.engine.deselect(item);
    }
  }

  /** Focuses the input before removal so an unmounted button cannot drop focus to the body. */
  @action
  removeItem(item: SelectItem, event?: MouseEvent): void {
    event?.stopPropagation();
    if (this.args.presenter.isLocked) {
      return;
    }
    this.args.focusInput();
    this.args.engine.deselect(item);
  }

  @action
  handleFieldFocus(event: FocusEvent): void {
    if ((event.target as Element).matches(".d-select__chip-remove")) {
      this.args.onChipFocus?.();
    }
    this.#revealFocused();
  }

  @action
  handleFieldResize(): void {
    this.args.onResize?.();
    this.#revealFocused();
  }

  #revealFocused(): void {
    const active = document.activeElement;
    const field = this.#element;
    if (
      this.args.roleMode !== "search" ||
      !field?.contains(active) ||
      !(active instanceof HTMLElement)
    ) {
      return;
    }
    if (active.matches(".d-select__input")) {
      field.scrollTop = field.scrollHeight;
    } else {
      active.scrollIntoView({ block: "nearest", inline: "nearest" });
    }
  }

  <template>
    <div
      class="d-select__chips
        {{if (eq @roleMode 'search') '--field'}}
        {{if this.summarized '--summarized'}}"
      {{this.watchField @value (if @selection.isResolved @selection.value)}}
      {{(if @onResize (modifier dOnResize this.handleFieldResize))}}
      {{on "focusin" this.handleFieldFocus}}
    >
      {{#if (eq @roleMode "search")}}
        {{! A wrapping label must activate the input before any remove button. }}
        <input
          class="d-select__label-sink"
          hidden
          style="display: none"
          type="text"
          {{on "click" @focusInput}}
        />
      {{/if}}
      {{! Removal restores focus here, not through the modifier: once the last chip goes this
        list falls back to the query input, which is outside the group. }}
      <ul
        aria-label={{i18n "d_select.selected_items"}}
        class="d-select__chip-list"
        {{(if
          @triggerChipsInteractive
          (modifier
            dRovingFocus
            tabStop=false
            orientation="horizontal"
            itemSelector=".d-select__chip-remove"
            restoreLostFocus=false
            onBoundary=this.exitChipsToInput
            onRegisterApi=@onRegisterChipRoving
          )
        )}}
      >
        <DAsyncContent @asyncData={{@selection}}>
          <:loading>
            {{#each (this.visibleChips this.chipSkeletons) key="key" as |row|}}
              <li class="d-select__chip" data-key={{row.key}}>
                {{#if @hasSelectionLoadingBlock}}
                  {{yield to="selectionLoading"}}
                {{else}}
                  <DSkeleton @variant="text" @width="6ch" />
                {{/if}}
              </li>
            {{/each}}
          </:loading>
          <:content as |chips|>
            {{#each (this.visibleChips chips) key="key" as |chip index|}}
              <li
                class="d-select__chip"
                data-name={{@engine.getSelectionLabel chip.item}}
                data-value={{this.chipValue chip}}
              >
                {{! Interactive chips are named through the remove button; display-only
                  chips expose their own label text. }}
                <span
                  aria-hidden={{if @triggerChipsInteractive "true"}}
                  class="d-select__chip-label"
                  id="{{this.chipIdPrefix}}-{{index}}-label"
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
                {{#if @triggerChipsInteractive}}
                  <button
                    {{! Name leads with the item, then how to remove it (e.g. "Orange, Press
                    Backspace or Delete to remove") so it reads as a selected item rather
                    than a bare action. }}
                    aria-disabled={{if @presenter.isLocked "true"}}
                    aria-label={{if
                      this.capabilities.touch
                      (i18n
                        "d_select.remove_item"
                        item=(@engine.getSelectionLabel chip.item)
                      )
                    }}
                    aria-labelledby={{unless
                      this.capabilities.touch
                      (concat
                        this.chipIdPrefix
                        "-"
                        index
                        "-label "
                        this.chipIdPrefix
                        "-"
                        index
                        "-remove"
                      )
                    }}
                    class="d-select__chip-remove"
                    tabindex="-1"
                    type="button"
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
                {{/if}}
              </li>
            {{/each}}
          </:content>
        </DAsyncContent>
      </ul>
      {{#if this.moreLabel}}
        <span aria-hidden="true" class="d-select__chips-more">
          {{~this.moreLabel~}}
        </span>
      {{/if}}
      {{#if this.summarized}}
        {{! The field's name and description already carry the held labels for assistive
          technology; the count is the visual stand-in for the hidden chips. }}
        <span aria-hidden="true" class="d-select__chips-summary">
          {{~this.summary~}}
        </span>
      {{/if}}
      {{#if @fieldRendersInput}}
        <ComboboxQueryInput
          aria-busy={{if
            (if (eq @roleMode "search") @engine.serverPending @pending)
            "true"
          }}
          aria-describedby={{@composeDescribedBy
            (if this.chipHint this.chipHintId)
            @describedBy
          }}
          aria-invalid={{if @invalid "true"}}
          class={{if (eq @roleMode "search") "d-select__filter"}}
          id={{@id}}
          @ariaOwns={{@ariaOwns}}
          @disabled={{@presenter.isDisabled}}
          @displayValue=""
          @editing={{@editing}}
          @engine={{@engine}}
          @expanded={{@expanded}}
          @label={{@label}}
          @listboxId={{@listboxId}}
          @onBlur={{@onBlur}}
          @onEdit={{@onEdit}}
          @onEscape={{@onEscape}}
          @onOpen={{@showMenu}}
          @onRequestClose={{@closeMenu}}
          @placeholder={{@placeholder}}
          @queryDisplay={{@queryDisplay}}
          @readonly={{@presenter.isReadonly}}
          @registerInput={{@registerInput}}
          @roleMode={{@roleMode}}
          @shouldSelectOnFocus={{@shouldSelectOnFocus}}
          @tabPassthrough={{@tabPassthrough}}
          {{on "paste" @onPaste}}
          {{(if
            @shouldCorrectKeyboardOcclusion
            (modifier keepAboveKeyboard @shouldCorrectKeyboardOcclusion)
          )}}
          {{on "keydown" @onInputKeydown capture=true}}
        />
        {{#if (and (eq @roleMode "search") @searchIcon)}}
          {{dIcon @searchIcon class="d-select__search-icon"}}
        {{/if}}
        {{#if this.chipHint}}
          <span class="sr-only" id={{this.chipHintId}}>
            {{this.chipHint}}
          </span>
        {{/if}}
      {{else if @placeholder}}
        {{! Without an inline query input there is nowhere else to say what to do, so an
          empty selection shows the placeholder here instead. }}
        <span class="d-select__placeholder">
          {{@placeholder}}
        </span>
      {{/if}}
    </div>
  </template>
}
