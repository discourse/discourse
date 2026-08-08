import { tracked } from "@glimmer/tracking";
import { registerDestructor } from "@ember/destroyable";
import { action } from "@ember/object";
import type DMenuInstance from "discourse/float-kit/lib/d-menu-instance";
import type { CapabilitiesService } from "discourse/services/capabilities";
import type { DRovingFocusApi } from "discourse/ui-kit/modifiers/d-roving-focus";
import SelectAnnouncer from "discourse/ui-kit/select/-internals/coordinators/select-announcer";
import VariantPresenter from "discourse/ui-kit/select/-internals/coordinators/variant-presenter";
import SelectEngine from "discourse/ui-kit/select/select-engine";

interface InteractionCoordinatorOptions {
  engine: SelectEngine;
  presenter: VariantPresenter;
  announcer: SelectAnnouncer;
  capabilities: CapabilitiesService;
  onShow: () => void;
  onClose: () => void;
  isMultiple: () => boolean | undefined;
}

export default class InteractionCoordinator {
  /**
   * The filter input element, handed to `dRovingFocus` as the combobox controller
   * (keydown binds to it; `aria-activedescendant` is written on it). In `typeahead` it is
   * the trigger input; in `button` it is the in-panel filter.
   */
  @tracked filterInput: HTMLElement | null = null;

  @tracked isExpanded = false;

  @tracked queryActive = false;

  // Whether focus is anywhere within the widget (the trigger input, or the open panel's
  // footer/options). A custom `:selection` block is a resting adornment, shown only while the
  // field is unfocused; focusing it — by Tab or by opening — reveals the plain editable label,
  // so keyboard focus and a click behave alike.
  @tracked triggerFocused = false;

  /**
   * Empty `@untriggers` for `typeahead`: keeps DMenu's default click-to-open on the whole
   * trigger while disabling close-on-click, so clicking the open trigger/input doesn't
   * toggle it shut (see template).
   */
  emptyTriggers: string[] = [];

  shouldCorrectKeyboardOcclusion = () =>
    this.#capabilities.isIOS && this.triggerFocused;

  #announcer: SelectAnnouncer;
  #capabilities: CapabilitiesService;

  // Controls for moving focus into the multi-select chip group, registered by the
  // chips' `dRovingFocus` (desktop only). Read imperatively from the keyboard handlers,
  // so a plain field rather than tracked; `null` while unregistered (mobile / single).
  #chipRoving: DRovingFocusApi | null = null;

  #engine: SelectEngine;
  #isMultiple: () => boolean | undefined;

  // The DMenu instance, captured on register so the engine can close the overlay and
  // the compat bridge can reach the trigger element.
  #menu: DMenuInstance | null = null;

  #onClose: () => void;
  #onShow: () => void;
  #presenter: VariantPresenter;

  // True only for the synchronous span of a programmatic focus whose caret is owned by
  // something other than the select-on-focus rule (opening from a pointer, or a label
  // activation), so the query input can tell those from a genuine keyboard focus (Tab-in,
  // which selects the label for replacement).
  #suppressSelectOnFocus = false;

  /**
   * A pointer press anywhere outside the widget ends the interaction: revert a focused
   * custom-selection field to its resting markup and drop DOM focus. Escape and option-select
   * keep focus (and the editable label); a click into another focusable element blurs on its
   * own. The overlay's own close-on-click-outside still fires in parallel.
   */
  #handleOutsidePointerDown = (event: PointerEvent): void => {
    if (!this.triggerFocused) {
      return;
    }
    if (this.#focusEscapedWidget(event.target)) {
      this.triggerFocused = false;
      this.filterInput?.blur();
    }
  };

  constructor({
    engine,
    presenter,
    announcer,
    capabilities,
    onShow,
    onClose,
    isMultiple,
  }: InteractionCoordinatorOptions) {
    this.#engine = engine;
    this.#presenter = presenter;
    this.#announcer = announcer;
    this.#capabilities = capabilities;
    this.#onShow = onShow;
    this.#onClose = onClose;
    this.#isMultiple = isMultiple;
    // A pointer press outside the widget ends the interaction, so a focused custom-selection
    // field reverts to its resting markup. The browser leaves DOM focus on the input when the
    // press lands on a non-focusable element, so revert explicitly rather than waiting for a
    // blur that never comes; the overlay's own close-on-click-outside runs in parallel.
    document.addEventListener(
      "pointerdown",
      this.#handleOutsidePointerDown,
      true
    );
    registerDestructor(this, () =>
      document.removeEventListener(
        "pointerdown",
        this.#handleOutsidePointerDown,
        true
      )
    );
  }

  get triggerElement(): HTMLElement | null {
    return this.#menu?.triggerElement ?? null;
  }

  /**
   * Captures the DMenu instance so the engine can close the overlay on select.
   *
   * @param api - The DMenu instance.
   */
  @action
  registerMenu(api: DMenuInstance): void {
    this.#menu = api;
  }

  @action
  focusChip(index: number): boolean {
    return this.#chipRoving?.focusIndex(index) ?? false;
  }

  @action
  focusInput(): void {
    this.filterInput?.focus();
  }

  /**
   * Captures the chip group's roving-focus controls so the query input can move focus
   * into the chips (ArrowLeft) and a keyboard removal can restore focus to a neighbor.
   * The modifier passes `null` on teardown.
   *
   * @param api - The roving-focus controls, or `null` on teardown.
   */
  @action
  registerChipRoving(api: DRovingFocusApi | null): void {
    this.#chipRoving = api;
  }

  /**
   * Captures the filter input and focuses it synchronously on open (before any async
   * results arrive — iOS only honors focus requested during the opening gesture).
   */
  @action
  captureFilter(element: HTMLElement): void {
    this.filterInput = element;
    element.focus({ preventScroll: true });
  }

  /**
   * For **desktop** `static` (a select-only combobox), captures the trigger `<div>` root as
   * the roving controller — `aria-activedescendant` is written on it and focus stays on it.
   * Attached to the DMenu root for every variant, so it self-gates: typeahead/multi keep the
   * input as their controller, `button`'s controller is the panel filter, and static in the
   * mobile modal uses focus mode (no controller — DOM focus moves into the listbox instead).
   */
  @action
  registerStaticController(element: HTMLElement): void {
    if (this.#presenter.isStatic && !this.#presenter.overlayIsModal) {
      this.filterInput = element;
    }
  }

  /**
   * Captures the desktop typeahead trigger input as the roving controller WITHOUT focusing
   * it — the trigger input is always present (not opened-into like the panel/modal input),
   * so focusing on insert would steal focus on page load.
   */
  @action
  registerTriggerInput(element: HTMLElement): void {
    this.filterInput = element;
  }

  @action
  handleClose(): void {
    // DMenu can invoke its close hook without a real state change (closing an already-closed
    // instance, teardown), so gate the consumer callback on an actual open→closed transition —
    // consumers can then treat `@onClose` as exactly one notification per close.
    const wasExpanded = this.isExpanded;
    this.isExpanded = false;
    this.#resetQueryOnClose();
    this.#announcer.releaseSession();
    if (wasExpanded) {
      this.#onClose();
    }
  }

  @action
  handleShow(): void {
    // DMenu can invoke its show hook without a real state change (clicking an already-open
    // trigger re-enters `show`), so gate the consumer callback on an actual closed→open
    // transition. The input still re-focuses on every click, which is the desired behavior.
    const wasExpanded = this.isExpanded;
    this.isExpanded = true;
    if (this.#presenter.isTypeahead) {
      this.#focusTriggerInput();
    }
    if (!wasExpanded) {
      this.#onShow();
    }
  }

  @action
  handleTriggerRootKeydown(event: KeyboardEvent): void {
    if (
      !this.#presenter.triggerIsControl ||
      this.isExpanded ||
      this.#presenter.isLocked ||
      event.isComposing
    ) {
      return;
    }
    // This listener sits on the DMenu trigger, which CONTAINS the chip list. A chip's remove
    // button is a genuine tab stop on the control variants (the `tabindex="-1"` seeding is gated
    // on desktop typeahead), so its keys bubble to here. Treating them as trigger keys both
    // swallows the button's own activation — `preventDefault()` below cancels the native click —
    // and lets Backspace clear the entire selection instead of acting on the focused chip. Only
    // a key aimed at the trigger itself is a trigger key.
    if (event.target !== event.currentTarget) {
      return;
    }
    if (
      event.key === "Enter" ||
      event.key === " " ||
      event.key === "ArrowDown" ||
      event.key === "ArrowUp"
    ) {
      event.preventDefault();
      this.#menu?.show();
      return;
    }
    // Keyboard clear for the control variants: they have no text input, so the closed trigger
    // IS their empty-query state and Backspace/Delete empties the selection. Not gated on
    // `@clearable` — that governs the visible × control only — for the same reason the typeahead
    // path is not: the family this replaces clears from an empty filter unconditionally, and
    // gating it here left a static select with no way out at all.
    if (
      this.#engine.hasValue &&
      (event.key === "Backspace" || event.key === "Delete")
    ) {
      event.preventDefault();
      this.#engine.clear();
    }
  }

  /**
   * Clears the whole selection from the trigger clear control, stopping the click from toggling
   * the overlay, then returns focus to the controller (the query input, or the trigger itself).
   */
  @action
  handleClear(event: MouseEvent): void {
    event.stopPropagation();
    if (this.#presenter.isLocked) {
      return;
    }
    this.#engine.clear();
    (this.filterInput ?? this.#menu?.triggerElement)?.focus();
  }

  @action
  beginQuery(): void {
    this.queryActive = true;
  }

  /**
   * Focuses the control when a wrapping label forwards its activation to the trigger's label
   * sink, so a caption behaves the way it does over a native field.
   *
   * The click is stopped short of the trigger root, which would otherwise read it as a trigger
   * press and open the overlay — a caption should put the user in the field, not in the list.
   * The caret is placed after the label rather than selecting it: overtype is what a keyboard
   * focus earns, and this is a pointer.
   */
  @action
  focusFromLabel(event: MouseEvent): void {
    event.stopPropagation();
    if (this.#presenter.isLocked) {
      return;
    }

    const input = this.filterInput;
    if (!input) {
      this.#menu?.triggerElement?.focus();
      return;
    }

    this.#suppressSelectOnFocus = true;
    input.focus();
    this.#suppressSelectOnFocus = false;

    if (input instanceof HTMLInputElement) {
      const end = input.value.length;
      input.setSelectionRange(end, end);
    }
  }

  /**
   * Whether a focus landing on the query input should select the displayed label (for
   * overtype). True for a genuine keyboard focus; false for a programmatic focus whose caret
   * belongs to the pointer that caused it.
   */
  @action
  shouldSelectOnFocus(): boolean {
    return !this.#suppressSelectOnFocus;
  }

  /**
   * Keeps focus in the trigger input when an option is pointer-selected: preventing the
   * `mousedown` default stops the input blurring, which would otherwise close the menu
   * before the option's `click` resolves. This matters for action rows and multi-select,
   * which keep the menu open.
   */
  @action
  preventPointerBlur(event: MouseEvent): void {
    if (this.#presenter.isTypeahead) {
      event.preventDefault();
    }
  }

  /**
   * Keeps focus in the query input when a press lands on the trigger but outside that input —
   * the caret indicator, the leading icon, or the padding around them.
   *
   * Without this the input blurs on `mousedown` and is refocused by the open that follows, and
   * that churn swallows the open entirely: pressing the caret did nothing whenever the input
   * already held focus, which is every time after the first use. A press that starts on the
   * input itself is left alone, so the browser still places the text caret where it was clicked.
   */
  @action
  preventTriggerBlur(event: MouseEvent): void {
    if (!this.#presenter.isTypeahead || this.#presenter.isLocked) {
      return;
    }

    const input = this.filterInput;
    const target = event.target as Node | null;
    if (input && target && (target === input || input.contains(target))) {
      return;
    }

    event.preventDefault();
  }

  /**
   * Desktop typeahead: focus left the trigger input. Close ONLY when focus genuinely moved
   * to a focusable element OUTSIDE the widget (a Tab-out / click into another field). A
   * `null` relatedTarget (clicking any non-focusable element) is deliberately ignored: an
   * in-trigger click on the label/caret must keep the menu open, and a truly-outside
   * non-focusable click is dismissed by close-on-click-outside instead. (Edge: a focus
   * loss with a null relatedTarget and no accompanying pointerdown — Tab into the browser's
   * own UI, a programmatic blur — won't close here; rare and accepted.)
   */
  @action
  handleTriggerBlur(event: FocusEvent): void {
    if (this.#focusEscapedWidget(event.relatedTarget)) {
      this.triggerFocused = false;
      this.#menu?.close();
    }
  }

  /**
   * Focus entered the trigger input. Reveal the editable label in place of any custom
   * `:selection` resting markup (a locked control never becomes editable, so it keeps its
   * markup). Paired with {@link handleTriggerBlur}, which restores the markup once focus leaves
   * the whole widget.
   */
  @action
  handleTriggerFocus(): void {
    if (!this.#presenter.isLocked) {
      this.triggerFocused = true;
    }
  }

  /**
   * A focusable footer control lost focus. Mirrors {@link handleTriggerBlur} — close when focus
   * leaves the whole widget — but DESKTOP ONLY: on mobile the overlay is a modal that owns its
   * dismissal (and whose `content` is undefined, so the containment guard can't run), and closes
   * with `focusTrigger: false` so a Tab-forward off the last footer control lands on the next page
   * control rather than being yanked back to the trigger.
   */
  @action
  handleFooterFocusOut(event: FocusEvent): void {
    if (this.#presenter.overlayIsModal) {
      return;
    }
    if (this.#focusEscapedWidget(event.relatedTarget)) {
      this.triggerFocused = false;
      this.#menu?.close({ focusTrigger: false });
    }
  }

  @action
  handleInputKeydown(event: KeyboardEvent): void {
    const input = event.target as HTMLInputElement;

    // Removing from the selection on an empty query: multi drops the last chip on Backspace
    // (repeat to empty it) — Backspace is the token-input convention, deleting backward toward
    // the chip before the caret; single clears on Backspace or Delete, since a lone value isn't
    // a directional token. Blocked while locked.
    //
    // Neither is gated on `@clearable`, which governs the visible × control only. The family
    // this replaces clears on Backspace-with-an-empty-filter unconditionally
    // (`select-kit/components/select-kit/select-kit-filter.gjs`), so gating it here left a
    // reader able to reach a value but not leave it, and contradicted the multi path directly
    // below, which was never gated.
    if (
      !event.isComposing &&
      input.value === "" &&
      this.#engine.hasValue &&
      !this.#presenter.isLocked
    ) {
      if (this.#isMultiple() && event.key === "Backspace") {
        event.preventDefault();
        this.#engine.deselectLast();
        return;
      }
      if (
        !this.#isMultiple() &&
        (event.key === "Backspace" || event.key === "Delete")
      ) {
        event.preventDefault();
        this.#engine.clear();
        return;
      }
    }

    // Desktop multi: ArrowLeft at the very start of the query moves focus into the chip
    // group (the chip nearest the input). Only the desktop trigger hosts the chips inline;
    // the mobile input lives in the modal, so entering the trigger chips would break out of
    // it. `preventDefault` only when a chip actually took focus, so an empty control (or a
    // loading re-flash) leaves ArrowLeft as a plain no-op caret move.
    if (
      this.#presenter.isDesktopTypeahead &&
      event.key === "ArrowLeft" &&
      !event.isComposing &&
      input.selectionStart === 0 &&
      input.selectionEnd === 0 &&
      this.#engine.hasValue &&
      this.#chipRoving?.focusLast()
    ) {
      event.preventDefault();
    }
  }

  closeMenu(): void {
    this.#menu?.close();
  }

  // True when focus moved to a real element outside both the trigger and the overlay content — the
  // signal that the whole widget lost focus. A `null` relatedTarget is treated as "stayed" (an
  // in-widget non-focusable click; a truly-outside non-focusable click is caught by
  // close-on-click-outside), matching the documented trigger-blur edge above.
  #focusEscapedWidget(next: EventTarget | null): boolean {
    if (!(next instanceof Node)) {
      return false;
    }
    const trigger = this.#menu?.triggerElement;
    const content = this.#menu?.content;
    return !(
      (trigger && trigger.contains(next)) ||
      (content && content.contains(next))
    );
  }

  /**
   * On open, moves focus into the query input so a click anywhere on the trigger (label,
   * caret, gaps — all open the menu via DMenu's trigger-root click) lands the caret in the
   * input on desktop. Null-safe on mobile: the query input lives in the modal and self-
   * focuses via `captureFilter` once it mounts (after this runs).
   */
  #focusTriggerInput(): void {
    this.#suppressSelectOnFocus = true;
    this.filterInput?.focus();
    this.#suppressSelectOnFocus = false;
  }

  /**
   * Resets the query so the next open starts clean, for every variant.
   *
   * A query is draft state that belongs to the session that typed it, and closing ends that
   * session — so a reopened list must never arrive still narrowed by a term the reader has moved
   * on from and can no longer see a reason for. That holds wherever the query lives: in the
   * trigger for a typeahead, or in the panel for a button variant, where it is doubly hidden
   * because the trigger is showing the value instead.
   *
   * Unguarded by the open→closed transition, unlike `@onClose`: a spurious close only fires when
   * the panel is already shut, where clearing is inert.
   *
   * Multi-select also resets on an add, because its menu stays open after selection.
   */
  #resetQueryOnClose(): void {
    this.#engine.setFilter("");
    this.queryActive = false;
  }
}
