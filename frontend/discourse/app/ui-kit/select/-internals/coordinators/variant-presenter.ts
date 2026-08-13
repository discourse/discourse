import { assert } from "@ember/debug";
import type { FloatContentRole } from "discourse/float-kit/lib/constants";
import type { DRovingFocusEntry } from "discourse/ui-kit/modifiers/d-roving-focus";
import SelectEngine, {
  type SelectValue,
} from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

export const SELECT_VARIANTS = {
  typeahead: "typeahead",
  button: "button",
  static: "static",
} as const;

export type SelectVariant =
  (typeof SELECT_VARIANTS)[keyof typeof SELECT_VARIANTS];

interface VariantPresenterArgs {
  value?: SelectValue;
  multiple?: boolean;
  labelField?: string;
  placeholder?: string;
  searchPlaceholder?: string;
  label?: string;
  variant?: SelectVariant;
  iconOnly?: boolean;
  caretIcon?: string | { open?: string; closed?: string };
  showCaret?: boolean;
  clearable?: boolean;
  disabled?: boolean;
  readonly?: boolean;
  retryable?: boolean;
  debounce?: boolean | number;
}

interface VariantPresenterOptions {
  getArgs: () => VariantPresenterArgs;
  engine: SelectEngine;
  shouldRenderInModal: (modalForMobile: boolean) => boolean;
  isExpanded: () => boolean;
  activeListboxId: () => string | undefined;
}

export default class VariantPresenter {
  #activeListboxId: () => string | undefined;
  #engine: SelectEngine;
  #getArgs: () => VariantPresenterArgs;
  #isExpanded: () => boolean;
  #shouldRenderInModal: (modalForMobile: boolean) => boolean;

  constructor(options: VariantPresenterOptions) {
    this.#activeListboxId = options.activeListboxId;
    this.#engine = options.engine;
    this.#getArgs = options.getArgs;
    this.#isExpanded = options.isExpanded;
    this.#shouldRenderInModal = options.shouldRenderInModal;
  }

  /** The trigger style; defaults to `typeahead`. */
  get variant(): SelectVariant {
    return this.#getArgs().variant ?? SELECT_VARIANTS.typeahead;
  }

  /** Whether the selected variant uses the typeahead query-input machinery. */
  get isTypeahead(): boolean {
    return this.variant === SELECT_VARIANTS.typeahead;
  }

  get triggerClass(): string {
    const classes = ["d-combobox__trigger"];
    if (this.isTypeahead) {
      classes.push("--typeahead");
    }
    if (this.#getArgs().multiple) {
      classes.push("--multiple");
    }
    if (this.triggerIsControl) {
      classes.push("--control");
    }
    if (this.iconOnly) {
      classes.push("--icon-only");
    }
    if (this.isDisabled) {
      classes.push("--disabled");
    } else if (this.isReadonly) {
      classes.push("--readonly");
    }
    return classes.join(" ");
  }

  /** Static/simple mode: a short unsearchable list; a WAI-ARIA select-only combobox. */
  get isStatic(): boolean {
    return this.variant === SELECT_VARIANTS.static;
  }

  /** Whether the search input lives in the panel rather than the trigger or nowhere. */
  get isPanelSearchable(): boolean {
    return !this.isTypeahead && !this.isStatic;
  }

  get triggerIsControl(): boolean {
    return this.isStatic || this.isPanelSearchable;
  }

  get triggerRootRole(): string | undefined {
    if (this.isStatic) {
      return "combobox";
    }
    if (this.isPanelSearchable) {
      return "button";
    }
    return undefined;
  }

  get triggerRootTabIndex(): string | undefined {
    // Disabled drops the control from the tab order; readonly stays focusable.
    if (this.isDisabled) {
      return undefined;
    }
    return this.triggerIsControl ? "0" : undefined;
  }

  /**
   * The ARIA role for the floated panel, decided by whether the panel owns a controller of its
   * own. Only the panel-searchable variant does; a select-only trigger is itself the combobox and
   * a typeahead keeps its query input in the trigger, so both leave the panel holding nothing but
   * the list. Wrapping that in a `dialog` puts a container between the combobox and the options
   * its `aria-activedescendant` points at, which is not the structure APG describes; `none` keeps
   * the element a presentational wrapper.
   *
   * A searchable panel is a genuine composite surface, which is what
   * {@link triggerRootHasPopup} promises there — dropping the role would make that promise false.
   * Mobile is unaffected either way, since there the panel is a `DModal`.
   */
  get panelContentRole(): FloatContentRole {
    return this.isPanelSearchable ? "dialog" : "none";
  }

  /**
   * `aria-haspopup` names what the trigger opens, and the two control variants open different
   * things.
   *
   * `static` is a select-only combobox: its `aria-controls` points at the listbox, and the
   * listbox is what a reader is being sent to — so `listbox` is both correct and consistent
   * with that reference.
   *
   * `button` is a disclosure. What it opens is the panel dialog, and that dialog holds a filter
   * input as well as the list. Calling it a listbox told a reader to expect a list and hid the
   * input they actually land on.
   */
  get triggerRootHasPopup(): string | undefined {
    if (this.isStatic) {
      return "listbox";
    }
    return this.isPanelSearchable ? "dialog" : undefined;
  }

  /**
   * The accessible name for the control-variant trigger root — the `role` lives on the `<div>`,
   * so the name must too. The typeahead/multi variants name their inner `role="combobox"` input
   * instead (via `ComboboxQueryInput @label`), so the root stays unnamed there.
   *
   * An author-supplied name REPLACES name-from-contents, so naming the root with the field label
   * alone made the held value unspeakable: a category picker showing "Support" announced only
   * "Options, button". The value is composed in rather than dropped, because the label still has
   * to say what the control is FOR — the visible text alone would not.
   *
   * Single-select only. A multi trigger renders chips, which are their own subtree rather than
   * one label, and folding them into a single string would fight the per-chip remove controls.
   */
  get triggerRootLabel(): string | undefined {
    if (!this.triggerIsControl) {
      return undefined;
    }
    if (this.#getArgs().multiple || !this.#engine.hasValue) {
      return this.ariaLabelText;
    }
    return i18n("d_select.label_with_value", {
      label: this.ariaLabelText,
      value: this.fallbackSelectionLabel,
    });
  }

  get triggerRootControls(): string | undefined {
    return this.triggerIsControl && this.#isExpanded()
      ? this.#activeListboxId()
      : undefined;
  }

  /**
   * `aria-disabled` / `aria-readonly` on the control-variant trigger root (the
   * `role="combobox"`/`role="button"` `<div>`). The typeahead/multi input carries the native
   * `disabled`/`readonly` attributes instead — a roleless `<div>`'s native attrs mean nothing.
   * A `role="button"` has no `aria-readonly` state, so a readonly button is announced
   * unavailable with `aria-disabled` instead.
   */
  get triggerRootDisabled(): string | undefined {
    const readonlyButton = this.isReadonly && this.isPanelSearchable;
    return this.triggerIsControl && (this.isDisabled || readonlyButton)
      ? "true"
      : undefined;
  }

  get triggerRootReadonly(): string | undefined {
    // Only the `role="combobox"` static trigger: `aria-readonly` is not a valid state for the
    // `role="button"` panel-searchable trigger (a button announces unavailability with
    // `aria-disabled`), so it is never emitted there.
    return this.isStatic && this.isReadonly ? "true" : undefined;
  }

  /** Whether the control cannot be opened or mutated (disabled or readonly). */
  get isDisabled(): boolean {
    return this.#getArgs().disabled ?? false;
  }

  get isReadonly(): boolean {
    return this.#getArgs().readonly ?? false;
  }

  get isLocked(): boolean {
    return this.isDisabled || this.isReadonly;
  }

  /** The resolved caret icon for the current open/closed state. */
  get caretIcon(): string {
    const arg = this.#getArgs().caretIcon;
    if (typeof arg === "string") {
      return arg;
    }
    return this.#isExpanded()
      ? (arg?.open ?? "angle-up")
      : (arg?.closed ?? "angle-down");
  }

  /** The caret shows unless a consumer explicitly opts out (icon-only triggers). */
  get showCaret(): boolean {
    return this.#getArgs().showCaret ?? true;
  }

  /**
   * Whether to render a label-less trigger. Effective only on the `button`/`static` single-select
   * variants; on a `typeahead` (editable input) or `multiple` (chips are the display) the arg is
   * inert. Asserts `@label` is present, since a suppressed label leaves the accessible name with no
   * visible text to fall back on.
   */
  get iconOnly(): boolean {
    const args = this.#getArgs();
    const requested = args.iconOnly ?? false;
    assert(
      "DSelect: `@iconOnly` requires `@label` — the trigger's visible text is suppressed, so `@label` provides its accessible name.",
      !requested || !!args.label
    );
    return requested && this.triggerIsControl && !args.multiple;
  }

  /** A source error offers a retry action unless a consumer opts out. */
  get retryable(): boolean {
    return this.#getArgs().retryable ?? true;
  }

  /** Whether the clear control renders: opted in, something selected, and not locked. */
  get showClear(): boolean {
    return (
      !!this.#getArgs().clearable && this.#engine.hasValue && !this.isLocked
    );
  }

  /** The clear control's accessible name — `"Clear all"` for multi, `"Clear selection"` otherwise. */
  get clearLabel(): string {
    return this.#getArgs().multiple
      ? i18n("d_select.clear_all")
      : i18n("d_select.clear");
  }

  /**
   * The list debounce forwarded to `DAsyncContent`. Defaults to whether the source is
   * server-backed (`engine.isAsync`) so a client source never flashes a skeleton, while a
   * consumer can force a delay with `true`/a number or disable it with `false`.
   */
  get debounce(): boolean | number {
    return this.#getArgs().debounce ?? this.#engine.isAsync;
  }

  /**
   * Whether the overlay renders as a mobile modal (an `aria-modal` dialog) rather than an
   * inline popover. Delegates to the `menu` service — the exact decision `<DMenu>` makes — so
   * the trigger's mobile/desktop behavior can never drift from what the overlay actually
   * renders. DSelect always opts into `@modalForMobile`, so it asks with `true`.
   */
  get overlayIsModal(): boolean {
    return this.#shouldRenderInModal(true);
  }

  /** Desktop typeahead: the query input lives in the trigger (host DOM). */
  get isDesktopTypeahead(): boolean {
    return this.isTypeahead && !this.overlayIsModal;
  }

  /** Mobile typeahead: the query input lives inside the modal (the trigger only shows the value). */
  get isMobileTypeahead(): boolean {
    return this.isTypeahead && this.overlayIsModal;
  }

  /**
   * Whether roving uses the `active-descendant` strategy — the combobox controller keeps DOM
   * focus and `aria-activedescendant` drives the highlight — rather than `roving-tabindex`
   * through the options. The controller is the query input for `typeahead` and the trigger
   * `<div>` for desktop `static` (a WAI-ARIA select-only combobox). Only **static in the mobile
   * modal** roves the tabindex: its list lives in an `aria-modal` dialog, so DOM focus must move
   * into the listbox rather than stay on the out-of-modal trigger.
   */
  get usesActiveRoving(): boolean {
    return !(this.isStatic && this.overlayIsModal);
  }

  /**
   * Whether to auto-highlight the first option on open. True for `typeahead`
   * (match-as-you-type) and desktop `static` (a select-only combobox — APG expects the
   * first/selected option active on open); static in the mobile modal instead moves DOM focus
   * onto the first option (see `focusListboxIfSimple`), and `button` waits for the user to
   * filter or arrow.
   *
   * Suppressed at the cap: there every unselected option is disabled, so the only navigable rows
   * are the selected ones, and auto-highlighting one would arm Enter to `deselect` and silently
   * drop a value — the same hazard {@link shouldActivateSelected} avoids for `multiple`.
   */
  get shouldAutoActivateFirst(): boolean {
    return (
      !this.#engine.atMaximum &&
      (this.isTypeahead || (this.isStatic && !this.overlayIsModal))
    );
  }

  /**
   * The reconcile key for a non-typeahead surface, where re-running on every render would reset
   * the user's arrow position. Typeahead keys on its freshly rebuilt items array instead (it
   * re-seeds on each keystroke), but a `button`/`static` list only needs to re-reconcile when the
   * navigable set changes: the filter, or the cap closing off the unselected options. Keying on
   * the cap state is what drops a stale `aria-activedescendant` off a now-disabled row.
   */
  get rovingNonTypeaheadKey(): string {
    return `${this.#engine.filter}::${this.#engine.atMaximum}`;
  }

  /**
   * The built-in limit hint, or `undefined` when neither bound applies. At-max wins over
   * below-min so a `minimum > maximum` misconfiguration still reads sensibly. Rendered in the
   * panel's top zone (a sibling of the list, not inside it), so it never competes with the
   * footer or an error body for the same edge.
   */
  get limitMessage(): string | undefined {
    if (this.#engine.atMaximum) {
      return i18n("d_select.max_reached", { count: this.#engine.maximum });
    }
    if (this.#engine.belowMinimum) {
      return i18n("d_select.min_not_reached", {
        count: this.#engine.minimum,
      });
    }
    return undefined;
  }

  /**
   * Whether to restore the cursor to the already-selected option on open. This outranks
   * {@link shouldAutoActivateFirst} and so also applies to `button`, whose "wait for the user"
   * rule exists to avoid pre-highlighting an *arbitrary* row — the user's own choice is not one.
   *
   * Excluded while filtering (the first match is what Enter should take, not a row the user
   * already holds) and for `multiple`, where activating a selected row would make Enter call
   * `deselect` and silently drop a value.
   */
  get shouldActivateSelected(): boolean {
    return (
      !this.#getArgs().multiple &&
      this.#engine.hasValue &&
      this.#engine.filter === ""
    );
  }

  /**
   * The fallback is the whole distinction between the four values: `button` restores a held
   * value but highlights nothing without one, so it cannot share `typeahead`'s.
   */
  get entryFocus(): DRovingFocusEntry {
    if (this.shouldActivateSelected) {
      return this.shouldAutoActivateFirst
        ? "selected-or-first"
        : "selected-or-none";
    }
    return this.shouldAutoActivateFirst ? "first" : "none";
  }

  /**
   * Whether any held id is displaying as an unresolved fallback, stamped on the trigger as
   * `data-unresolved`. The state is otherwise expressed differently per variant — a muted span
   * for a chip or a control, but only the input's value text on a desktop typeahead, where
   * there is no element to mark — so this is the one hook that reads the same everywhere.
   */
  get hasUnresolvedSelection(): boolean {
    return this.#engine.hasUnresolvedSelection;
  }

  get fallbackSelectionLabel(): string {
    const args = this.#getArgs();
    const resolved = this.#engine.resolveSingleSync(args.value);
    if (resolved?.__unresolved) {
      // The plain input can't render the icon/muted treatment chips get, so the label has to
      // carry the state itself. A consumer-named fallback ("Topic #123") already reads as
      // one; only the bare-id default needs the suffix to not look like a real label.
      return this.#engine.isCustomUnresolvedItem(resolved)
        ? this.#engine.getItemLabel(resolved)
        : i18n("d_select.unresolved_value", { value: args.value });
    }
    return this.#engine.getSingleSelectionLabel(args.value);
  }

  get labelField(): string {
    return this.#getArgs().labelField ?? "name";
  }

  get queryPlaceholder(): string {
    if (this.#engine.hasValue) {
      return "";
    }
    return this.#getArgs().placeholder || i18n("d_select.add_placeholder");
  }

  /** The filter input's placeholder (the consumer's `@searchPlaceholder` or a default). */
  get searchPlaceholderText(): string {
    return (
      this.#getArgs().searchPlaceholder ?? i18n("d_select.search_placeholder")
    );
  }

  /** The combobox/listbox accessible name (the consumer's `@label` or a default). */
  get ariaLabelText(): string {
    return this.#getArgs().label ?? i18n("d_select.label");
  }
}
