import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import measurePlaceholder from "discourse/ui-kit/select/-internals/modifiers/measure-placeholder";
import type SelectEngine from "discourse/ui-kit/select/select-engine";

interface ComboboxQueryInputSignature {
  Element: HTMLInputElement;
  Args: {
    /** Search fields omit disclosure semantics while their list stays visible. */
    roleMode?: "combobox" | "search";
    /** The headless engine; the input reads/writes only its `filter` (the query). */
    engine: SelectEngine;
    /**
     * The listbox id, wired as `aria-controls`/`aria-owns` while open. Absent while no
     * listbox is rendered, so neither attribute points at a missing element.
     */
    listboxId?: string;
    /** Whether the overlay is open (drives `aria-expanded` and the open guards). */
    expanded: boolean;
    /** The input's accessible name (`aria-label`). */
    label?: string;
    /** Ids of the elements naming the input, used instead of `label`. */
    labelledBy?: string;
    /** The input placeholder; empty omits the attribute. */
    placeholder?: string;
    /** Space-separated ids describing the input, such as a hint or a form's validation message. */
    describedBy?: string;
    /** Publishes the placeholder's width, for a chip row that keeps a long placeholder whole. */
    measurePlaceholder?: boolean;
    /** Defaults to the resting display until editing; always shows the engine's filter. */
    queryDisplay?: "editing" | "always";
    /** Selected label displayed in the input before query editing begins. */
    displayValue?: string;
    /**
     * Whether a `@displayValue` that appears (transitions from empty to a label) should be
     * selected for overtype. True only for a resting-suppressed selection label, which appears
     * when the field is focused; a stable label that merely resolves late keeps its caret.
     */
    selectLabelOnAppear?: boolean;
    /** Whether the input is displaying the active query. */
    editing?: boolean;
    /**
     * Locks the input: no typing, no open. `disabled` also drops it from the tab order (native
     * `disabled`); `readonly` keeps it focusable (native `readonly`). Both block the open/edit
     * paths this component owns (type-to-open, ArrowDown-to-open), which native attrs alone
     * don't fully cover on a `readonly` input.
     */
    disabled?: boolean;
    readonly?: boolean;
    /**
     * Emit `aria-owns` (in addition to `aria-controls`) while open. Needed on desktop,
     * where the listbox is portaled out of the input's subtree; omitted on mobile, where
     * both live inside the same modal.
     */
    ariaOwns?: boolean;
    /** Opens the overlay (wired to the menu's `show`). */
    onOpen?: () => void;
    /** Closes the overlay (Escape) — the parent resets the query on close. */
    onRequestClose?: () => void;
    /** Overrides Escape's close action. Defaults to onRequestClose. */
    onEscape?: (event: KeyboardEvent) => void;
    /** Lets Tab bubble to the host. Defaults to false so Tab exits the trigger. */
    tabPassthrough?: boolean;
    /** Focus left the input; the parent decides whether that should close the overlay. */
    onBlur?: (event: FocusEvent) => void;
    /** Marks the first edit so the query replaces the selected label. */
    onEdit?: () => void;
    /**
     * Whether a focus should select the displayed label for overtype. Returns false for the
     * programmatic focus fired while opening (so a pointer click keeps its caret position),
     * true for a genuine keyboard focus. Defaults to selecting when not provided.
     */
    shouldSelectOnFocus?: () => boolean;
    /** Captures the input element (fed to `dRovingFocus` as the combobox controller). */
    registerInput: (element: HTMLInputElement) => void;
  };
}

/** Query input shared by typeahead triggers and visible-list search fields. */
export default class ComboboxQueryInput extends Component<ComboboxQueryInputSignature> {
  // Set on `pointerdown` (which fires just before the native focus) so the focus handler
  // knows this focus came from a pointer press and must leave the caret where the click
  // put it, rather than selecting the whole label.
  #pointerFocus = false;

  get isCombobox(): boolean {
    return this.args.roleMode !== "search";
  }

  get value(): string {
    return this.args.queryDisplay === "always" || this.args.editing
      ? this.args.engine.filter
      : (this.args.displayValue ?? this.args.engine.filter);
  }

  /** `aria-controls` only resolves to a live element while the listbox is rendered. */
  get controlsId(): string | undefined {
    return this.args.roleMode === "search" || this.args.expanded
      ? this.args.listboxId
      : undefined;
  }

  /** `aria-owns` (desktop, cross-portal) only while the listbox is rendered. */
  get ownsId(): string | undefined {
    return this.args.ariaOwns && this.args.expanded
      ? this.args.listboxId
      : undefined;
  }

  /**
   * The id of a visually hidden copy of the placeholder, listed first among the input's
   * descriptions. Only while the input has another description: some screen readers stop
   * speaking a placeholder once `aria-describedby` is set, so the requirement it states would
   * go unheard.
   */
  get placeholderDescriptionId(): string | undefined {
    return this.args.placeholder && this.args.describedBy
      ? `${guidFor(this)}-placeholder`
      : undefined;
  }

  /** An empty name is no name: the caption, or nothing, names the input instead. */
  get labelAttribute(): string | undefined {
    return this.args.labelledBy ? undefined : this.args.label || undefined;
  }

  get placeholderAttribute(): string | undefined {
    return this.args.placeholder || undefined;
  }

  get describedBy(): string | undefined {
    const ids = [this.placeholderDescriptionId, this.args.describedBy].filter(
      Boolean
    );
    return ids.length ? ids.join(" ") : undefined;
  }

  /** No typing, no open when disabled or readonly. */
  get #locked(): boolean {
    return !!(this.args.disabled || this.args.readonly);
  }

  @action
  handleInput(event: Event): void {
    // Wait for `compositionend` before searching so a half-composed CJK string
    // doesn't filter or open the list mid-composition.
    if ((event as InputEvent).isComposing) {
      return;
    }
    this.#commitQuery((event.target as HTMLInputElement).value);
  }

  @action
  handleCompositionEnd(event: CompositionEvent): void {
    this.#commitQuery((event.target as HTMLInputElement).value);
  }

  @action
  handlePointerDown(): void {
    this.#pointerFocus = true;
  }

  @action
  handleFocus(event: FocusEvent): void {
    // A pointer press positions the caret at the click; the browser owns that, so don't
    // select the label over it. Keyboard focus (no preceding pointerdown) still selects.
    const pointerFocus = this.#pointerFocus;
    this.#pointerFocus = false;
    if (pointerFocus) {
      return;
    }

    if (this.args.shouldSelectOnFocus?.() ?? true) {
      this.#selectDisplayValue(event.target as HTMLInputElement);
    }
  }

  @action
  handleKeydown(event: KeyboardEvent): void {
    // Neutralize DMenu's trigger-root `forwardTabToContent` (a bubble-phase listener):
    // stop the bubble but don't preventDefault, so focus leaves the widget naturally. A panel
    // with a control of its own has already claimed this press in the capture phase, so this
    // is only reached when leaving really is the right outcome.
    if (event.key === "Tab") {
      if (!this.args.tabPassthrough) {
        event.stopPropagation();
      }
      return;
    }

    // Mid-composition every key belongs to the IME, so composing a candidate never opens or
    // selects. `dRovingFocus` declines composing keys itself, so this only has to stop the
    // open/select handling below.
    if (event.isComposing) {
      return;
    }

    if (
      !this.args.expanded &&
      (event.key === "ArrowDown" || event.key === "ArrowUp")
    ) {
      event.preventDefault();
      if (!this.#locked) {
        this.args.onOpen?.();
      }
      return;
    }

    if (event.key === "Escape") {
      if (this.args.onEscape) {
        this.args.onEscape(event);
      } else {
        event.preventDefault();
        this.args.onRequestClose?.();
      }
      return;
    }
    // Enter and the arrows (while open) fall through to `dRovingFocus`.
  }

  @action
  handleFocusout(event: FocusEvent): void {
    // Clear a pointerdown that never produced a focus (e.g. clicking an already-focused
    // input) so the next keyboard focus is not mistaken for a pointer focus.
    this.#pointerFocus = false;
    this.args.onBlur?.(event);
  }

  @action
  selectOnDisplayValue(element: HTMLInputElement): void {
    // Fires when `@displayValue` transitions "" -> label — for a custom-selection field this
    // happens the moment it gains focus, in the same render that patches `value`, so the freshly
    // shown label is left selected and ready to overtype. Gated on `selectLabelOnAppear` so a
    // stable label that merely resolves late under an already-focused input keeps its caret. The
    // remaining focus/editing/empty guards live in the callee.
    if (this.args.selectLabelOnAppear) {
      this.#selectDisplayValue(element);
    }
  }

  #selectDisplayValue(element: HTMLInputElement): void {
    if (
      !this.args.editing &&
      this.args.displayValue &&
      document.activeElement === element
    ) {
      element.select();
    }
  }

  #commitQuery(value: string): void {
    if (this.#locked) {
      return;
    }
    this.args.onEdit?.();
    this.args.engine.setFilter(value);
    if (!this.args.expanded) {
      this.args.onOpen?.();
    }
  }

  <template>
    <input
      aria-autocomplete="list"
      aria-controls={{this.controlsId}}
      aria-describedby={{this.describedBy}}
      aria-expanded={{if this.isCombobox (if @expanded "true" "false")}}
      aria-haspopup={{if this.isCombobox "listbox"}}
      aria-label={{this.labelAttribute}}
      aria-labelledby={{@labelledBy}}
      aria-owns={{this.ownsId}}
      autocomplete="off"
      class="d-select__input"
      disabled={{@disabled}}
      placeholder={{this.placeholderAttribute}}
      readonly={{@readonly}}
      role={{if this.isCombobox "combobox"}}
      type={{if this.isCombobox "text" "search"}}
      value={{this.value}}
      ...attributes
      {{on "input" this.handleInput}}
      {{on "compositionend" this.handleCompositionEnd}}
      {{on "keydown" this.handleKeydown}}
      {{! pointerdown is required: it must flag the pointer press before the native focus
        fires between pointerdown and pointerup, so the focus handler can skip the select. }}
      {{! eslint-disable-next-line ember/template-no-pointer-down-event-binding }}
      {{on "pointerdown" this.handlePointerDown}}
      {{on "focus" this.handleFocus}}
      {{on "focusout" this.handleFocusout}}
      {{didInsert @registerInput}}
      {{didUpdate this.selectOnDisplayValue @displayValue}}
      {{(if
        @measurePlaceholder
        (modifier measurePlaceholder this.placeholderAttribute)
      )}}
    />
    {{#if this.placeholderDescriptionId}}
      <span class="sr-only" id={{this.placeholderDescriptionId}}>
        {{~@placeholder~}}
      </span>
    {{/if}}
  </template>
}
