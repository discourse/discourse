import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import booleanString from "discourse/helpers/boolean-string";
import type SelectEngine from "discourse/ui-kit/select/select-engine";

interface ComboboxQueryInputSignature {
  Element: HTMLInputElement;
  Args: {
    /** The headless engine; the input reads/writes only its `filter` (the query). */
    engine: SelectEngine;
    /** The listbox id, wired as `aria-controls`/`aria-owns` while open. */
    listboxId: string;
    /** Whether the overlay is open (drives `aria-expanded` and the open guards). */
    expanded: boolean;
    /** The input's accessible name (`aria-label`). */
    label?: string;
    /** The input placeholder. */
    placeholder?: string;
    /** Selected label displayed in the input before query editing begins. */
    displayValue?: string;
    /** Whether the input is displaying the active query. */
    editing?: boolean;
    /**
     * Emit `aria-owns` (in addition to `aria-controls`) while open. Needed on desktop,
     * where the listbox is portaled out of the input's subtree; omitted on mobile, where
     * both live inside the same modal.
     */
    ariaOwns?: boolean;
    /** Opens the overlay (wired to the menu's `show`). */
    onOpen: () => void;
    /** Closes the overlay (Escape) — the parent resets the query on close. */
    onRequestClose: () => void;
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
    registerInput: (element: HTMLElement) => void;
  };
}

/**
 * The `role="combobox"` text input at the heart of the typeahead trigger. It is
 * deliberately **arity-agnostic**: it carries the engine's `filter` and can display a
 * selected-label fallback until query editing begins. Custom selection markup and chips
 * remain siblings in the composite trigger box. It owns the combobox keyboard model that
 * DMenu's default button trigger does not:
 *
 * - **Tab** is stopped from bubbling to DMenu's trigger-root `forwardTabToContent`, so it
 *   exits the widget (and the resulting blur closes the overlay) instead of being pulled
 *   into the portaled list.
 * - **ArrowDown/ArrowUp** open the overlay when closed; once open they reach `dRovingFocus`
 *   (bound to this same input) to move the virtual highlight.
 * - **Escape** closes; **Enter** is handled by `dRovingFocus` (activates the highlighted
 *   option) — except mid-composition, where both are suppressed so an IME candidate commit
 *   doesn't select an option.
 *
 * Arrow/Enter navigation keeps DOM focus on this input (WAI-ARIA `active` mode), so the
 * user can keep typing while navigating results.
 */
export default class ComboboxQueryInput extends Component<ComboboxQueryInputSignature> {
  // Set on `pointerdown` (which fires just before the native focus) so the focus handler
  // knows this focus came from a pointer press and must leave the caret where the click
  // put it, rather than selecting the whole label.
  #pointerFocus = false;

  get value(): string {
    return this.args.editing
      ? this.args.engine.filter
      : (this.args.displayValue ?? this.args.engine.filter);
  }

  /** `aria-controls` only resolves to a live element while the listbox is rendered. */
  get controlsId(): string | undefined {
    return this.args.expanded ? this.args.listboxId : undefined;
  }

  /** `aria-owns` (desktop, cross-portal) only while the listbox is rendered. */
  get ownsId(): string | undefined {
    return this.args.ariaOwns && this.args.expanded
      ? this.args.listboxId
      : undefined;
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
    // stop the bubble but don't preventDefault, so focus leaves the widget naturally.
    if (event.key === "Tab") {
      event.stopPropagation();
      return;
    }

    // Mid-composition: swallow the navigation/commit keys (and block `dRovingFocus`, which
    // also listens on this input) so composing a candidate never opens or selects.
    if (event.isComposing) {
      if (
        event.key === "Enter" ||
        event.key === "ArrowDown" ||
        event.key === "ArrowUp"
      ) {
        event.stopImmediatePropagation();
      }
      return;
    }

    if (
      !this.args.expanded &&
      (event.key === "ArrowDown" || event.key === "ArrowUp")
    ) {
      event.preventDefault();
      this.args.onOpen();
      return;
    }

    if (event.key === "Escape") {
      event.preventDefault();
      this.args.onRequestClose();
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
    this.args.onEdit?.();
    this.args.engine.setFilter(value);
    if (!this.args.expanded) {
      this.args.onOpen();
    }
  }

  <template>
    <input
      type="text"
      class="d-combobox__input"
      role="combobox"
      aria-autocomplete="list"
      aria-haspopup="listbox"
      autocomplete="off"
      aria-label={{@label}}
      aria-expanded={{booleanString @expanded omitFalse=false}}
      aria-controls={{this.controlsId}}
      aria-owns={{this.ownsId}}
      placeholder={{@placeholder}}
      value={{this.value}}
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
      ...attributes
    />
  </template>
}
