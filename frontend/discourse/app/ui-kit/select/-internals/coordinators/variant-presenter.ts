import type { FloatContentRole } from "discourse/float-kit/lib/constants";
import { bind } from "discourse/lib/decorators";
import type { DRovingFocusEntry } from "discourse/ui-kit/modifiers/d-roving-focus";
import type { SelectionNavigationTarget } from "discourse/ui-kit/select/-internals/coordinators/field-keyboard";
import SelectPresenterBase, {
  type OptionsPresenter,
  type SelectPresenterArgs,
} from "discourse/ui-kit/select/-internals/coordinators/select-presenter-base";
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

interface VariantPresenterArgs extends SelectPresenterArgs {
  value?: SelectValue;
  multiple?: boolean;
  /** Maximum trigger chips; zero renders only the selected count. */
  maxVisibleChips?: number;
  variant?: SelectVariant;
}

interface VariantPresenterOptions {
  getArgs: () => VariantPresenterArgs;
  engine: SelectEngine;
  shouldRenderInModal: (modalForMobile: boolean) => boolean;
  isExpanded: () => boolean;
  activeListboxId: () => string | undefined;
}

export default class VariantPresenter
  extends SelectPresenterBase
  implements OptionsPresenter
{
  #activeListboxId: () => string | undefined;
  #engine: SelectEngine;
  #getArgs: () => VariantPresenterArgs;
  #isExpanded: () => boolean;
  #shouldRenderInModal: (modalForMobile: boolean) => boolean;

  constructor(options: VariantPresenterOptions) {
    super(options);
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
    const classes = ["d-select__trigger"];
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

  /**
   * Whether the root is a disclosure button: the panel-searchable variant, and the mobile
   * typeahead, whose query input lives in the modal the root opens.
   */
  get triggerIsButton(): boolean {
    return this.isPanelSearchable || this.isMobileTypeahead;
  }

  /**
   * Whether the root is the keyboard stop. Only the desktop typeahead keeps focus on an input in
   * the trigger; everywhere else the root is the only thing to Tab to before the overlay opens.
   */
  get triggerTakesFocus(): boolean {
    return this.triggerIsControl || this.isMobileTypeahead;
  }

  get triggerRootRole(): string | undefined {
    if (this.isStatic) {
      return "combobox";
    }
    if (this.triggerIsButton) {
      return "button";
    }
    return undefined;
  }

  get triggerRootTabIndex(): string | undefined {
    // Disabled drops the control from the tab order; readonly stays focusable.
    if (this.isDisabled) {
      return undefined;
    }
    return this.triggerTakesFocus ? "0" : undefined;
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
   * `aria-haspopup` names what the trigger opens, and the control variants open different
   * things.
   *
   * `static` is a select-only combobox: its `aria-controls` points at the listbox, and the
   * listbox is what a reader is being sent to — so `listbox` is both correct and consistent
   * with that reference.
   *
   * A button trigger is a disclosure. What it opens is a dialog (the panel, or the mobile
   * typeahead's modal), and that dialog holds a query input as well as the list. Calling it a
   * listbox told a reader to expect a list and hid the input they actually land on.
   */
  get triggerRootHasPopup(): string | undefined {
    if (this.isStatic) {
      return "listbox";
    }
    return this.triggerIsButton ? "dialog" : undefined;
  }

  /**
   * The accessible name for a focusable trigger root — the `role` lives on the `<div>`, so the
   * name must too. The desktop typeahead names its inner `role="combobox"` input instead (via
   * `ComboboxQueryInput @label`), so the root stays unnamed there.
   *
   * An author-supplied name REPLACES name-from-contents, so naming the root with the field label
   * alone made the held value unspeakable: a category picker showing "Support" announced only
   * "Options, button". The value is composed in rather than dropped, because the label still has
   * to say what the control is FOR — the visible text alone would not.
   *
   * Multi-select held labels are exposed through a separate description.
   */
  get triggerRootLabel(): string | undefined {
    if (!this.triggerTakesFocus) {
      return undefined;
    }
    if (this.#getArgs().multiple || !this.#engine.hasValue) {
      return this.selectionLabel;
    }
    return i18n("d_select.label_with_value", {
      label: this.ariaLabelText,
      value: this.fallbackSelectionLabel,
    });
  }

  get triggerRootControls(): string | undefined {
    return this.triggerTakesFocus && this.#isExpanded()
      ? this.#activeListboxId()
      : undefined;
  }

  /**
   * `aria-disabled` / `aria-readonly` on a focusable trigger root (the
   * `role="combobox"`/`role="button"` `<div>`). The desktop typeahead input carries the native
   * `disabled`/`readonly` attributes instead — a roleless `<div>`'s native attrs mean nothing.
   * A `role="button"` has no `aria-readonly` state, so a readonly button is announced
   * unavailable with `aria-disabled` instead.
   */
  get triggerRootDisabled(): string | undefined {
    const readonlyButton = this.isReadonly && this.triggerIsButton;
    return this.triggerTakesFocus && (this.isDisabled || readonlyButton)
      ? "true"
      : undefined;
  }

  get triggerRootReadonly(): string | undefined {
    // Only the `role="combobox"` static trigger: `aria-readonly` is not a valid state for a
    // `role="button"` trigger (a button announces unavailability with `aria-disabled`), so it is
    // never emitted there.
    return this.isStatic && this.isReadonly ? "true" : undefined;
  }

  /** The resolved caret icon for the current open/closed state. */
  get caretIcon(): string {
    const arg = this.#engine.resolvedOptions.caretIcon;
    if (typeof arg === "string") {
      return arg;
    }
    return this.#isExpanded()
      ? (arg?.open ?? "angle-up")
      : (arg?.closed ?? "angle-down");
  }

  /** The caret shows unless a consumer explicitly opts out (icon-only triggers). */
  get showCaret(): boolean {
    return this.#engine.resolvedOptions.showCaret ?? true;
  }

  /**
   * Whether to render a label-less trigger. Effective only on the `button`/`static` single-select
   * variants; on a `typeahead` (editable input) or `multiple` (chips are the display) the arg is
   * inert. Options resolution ignores it with a warning when no accessible label resolves.
   */
  get iconOnly(): boolean {
    return (
      !!this.#engine.resolvedOptions.iconOnly &&
      this.triggerIsControl &&
      !this.#getArgs().multiple
    );
  }

  /** The resolved decorative leading trigger icon. */
  get icon(): string | undefined {
    return this.#engine.resolvedOptions.icon;
  }

  /** Whether the clear control renders: opted in, something selected, and not locked. */
  get showClear(): boolean {
    return (
      !!this.#engine.resolvedOptions.clearable &&
      this.#engine.hasValue &&
      !this.isLocked
    );
  }

  /** The clear control's accessible name — `"Clear all"` for multi, `"Clear selection"` otherwise. */
  get clearLabel(): string {
    return this.#getArgs().multiple
      ? i18n("d_select.clear_all")
      : i18n("d_select.clear");
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

  /** Whether the trigger field contains a query input. */
  get fieldRendersInput(): boolean {
    return this.isDesktopTypeahead;
  }

  /** Only uncapped desktop typeaheads offer removal in the trigger. */
  get triggerChipsInteractive(): boolean {
    return this.isDesktopTypeahead && this.maxVisibleChips === undefined;
  }

  /** Compact fields enter the panel strip; uncapped fields enter their trigger chips. */
  get previousKeyTarget(): SelectionNavigationTarget {
    if (!this.isDesktopTypeahead) {
      return undefined;
    }
    return this.triggerChipsInteractive ? "chips" : "strip";
  }

  /** The trigger's chip budget; undefined preserves all chips. */
  get maxVisibleChips(): number | undefined {
    const count = this.#getArgs().maxVisibleChips;
    return count === undefined ? undefined : Math.max(0, Math.floor(count));
  }

  /** Held labels describe display-only triggers, including locked fields. */
  get describeHeldLabels(): boolean {
    return !!this.#getArgs().multiple && !this.triggerChipsInteractive;
  }

  /** Local control lists already expose held rows with checked states. */
  get selectionStripEligible(): boolean {
    return (
      this.describeHeldLabels &&
      this.#engine.hasValue &&
      (this.overlayIsModal || this.isDesktopTypeahead || this.#engine.isAsync)
    );
  }

  /** Compact and overflow controls announce the entire held count. */
  get selectionLabel(): string {
    if (this.#getArgs().multiple && this.maxVisibleChips !== undefined) {
      const value = this.#engine.value;
      return i18n("d_select.label_with_count", {
        label: this.ariaLabelText,
        count: Array.isArray(value) ? value.length : 0,
      });
    }
    return this.ariaLabelText;
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
   * Suppressed at the cap: every unselected option is disabled, so only selected rows could seed
   * entry, and auto-highlighting one would arm Enter to `deselect` and silently
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
   * entry policy changes: the filter, reload nonce, or cap state. Reconciliation preserves a
   * surviving cursor even when the cap disables its row.
   */
  get rovingNonTypeaheadKey(): string {
    return `${this.#engine.queryKey}::${this.#engine.atMaximum}`;
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
    const value = this.#engine.value;
    const resolved = this.#engine.resolveSingleSync(value);
    if (resolved?.__unresolved) {
      return this.#engine.getSelectionLabel(resolved);
    }
    return this.#engine.getSingleSelectionLabel(value);
  }

  get queryPlaceholder(): string {
    if (this.#engine.hasValue || this.#engine.pending) {
      return "";
    }
    return this.placeholder || i18n("d_select.add_placeholder");
  }

  /** The filter input's resolved placeholder, or a default. */
  get searchPlaceholderText(): string {
    return (
      this.#engine.resolvedOptions.searchPlaceholder ??
      i18n("d_select.search_placeholder")
    );
  }

  /** Keeps typeahead reconciliation keyed to the displayed array. */
  @bind
  rovingItemsKey(items: readonly unknown[]): readonly unknown[] | string {
    return this.isTypeahead ? items : this.rovingNonTypeaheadKey;
  }
}
