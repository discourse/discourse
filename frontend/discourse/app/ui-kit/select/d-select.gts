import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import { getOwner } from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { cancel, next as nextRunloop, schedule } from "@ember/runloop";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import type { MenuOptions } from "discourse/float-kit/lib/constants";
import type DMenuInstance from "discourse/float-kit/lib/d-menu-instance";
import type Menu from "discourse/float-kit/services/menu";
import booleanString from "discourse/helpers/boolean-string";
import { makeArray } from "discourse/lib/helpers";
import discourseLater from "discourse/lib/later";
import type A11y from "discourse/services/a11y";
import { and, or } from "discourse/truth-helpers";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DButton from "discourse/ui-kit/d-button";
import DFilterInput from "discourse/ui-kit/d-filter-input";
import DLoadMore from "discourse/ui-kit/d-load-more";
import DSkeleton from "discourse/ui-kit/d-skeleton";
import dElement from "discourse/ui-kit/helpers/d-element";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dRovingFocus, {
  type DRovingFocusApi,
} from "discourse/ui-kit/modifiers/d-roving-focus";
import ComboboxQueryInput from "discourse/ui-kit/select/-internals/combobox-query-input";
import SelectItem from "discourse/ui-kit/select/-internals/select-item";
import SelectionLabel from "discourse/ui-kit/select/-internals/selection-label";
import TriggerFrame from "discourse/ui-kit/select/-internals/trigger-frame";
import SelectEngine, {
  type SelectDescriptor,
  type SelectEngineOptions,
  type SelectItem as SelectItemModel,
  selectItemLabel,
  type SelectLoadOptions,
  type SelectValue,
} from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

const SELECT_VARIANTS = {
  typeahead: "typeahead",
  button: "button",
  static: "static",
} as const;
// A source that answers faster than this never shows a placeholder, so a quick server does
// not flash one; only a wait long enough to read as "stuck" gets visible feedback.
const LOADING_FEEDBACK_DELAY = 250;

export type SelectVariant =
  (typeof SELECT_VARIANTS)[keyof typeof SELECT_VARIANTS];

interface SelectListContent {
  rawItems: SelectItemModel[];
}

interface DSelectSignature {
  Args: {
    value?: SelectValue;
    multiple?: boolean;
    identifiers?: string | string[];
    identifier?: string;
    items?: SelectEngineOptions["items"];
    load?: SelectEngineOptions["load"];
    filterBy?: SelectEngineOptions["filterBy"];
    valueField?: string;
    labelField?: string;
    selected?: SelectItemModel | SelectItemModel[];
    resolveValue?: SelectEngineOptions["resolveValue"];
    resolveValues?: SelectEngineOptions["resolveValues"];
    allowCreate?: SelectEngineOptions["allowCreate"];
    createItem?: SelectEngineOptions["createItem"];
    createUnresolvedItem?: SelectEngineOptions["createUnresolvedItem"];
    specialItems?: SelectEngineOptions["specialItems"];
    onChange?: SelectEngineOptions["onChange"];
    placeholder?: string;
    searchPlaceholder?: string;
    noResultsLabel?: string;
    label?: string;
    skeletonCount?: number;
    selectedIcon?: string;
    /**
     * The trigger style. `"typeahead"` (default) makes the trigger itself a
     * `role="combobox"` input; `"button"` keeps a button trigger with the filter in the
     * panel; `"static"` is a short, unsearchable list (the native-`<select>` replacement).
     */
    variant?: SelectVariant;
    /** A leading (decorative) icon in the trigger. */
    icon?: string;
    /**
     * The caret icon. A bare string is used in both states; a `{ open, closed }` hash swaps on
     * open (keyed off the overlay's expanded state). Defaults to `angle-up` / `angle-down`.
     */
    caretIcon?: string | { open?: string; closed?: string };
    /**
     * Show a clear control that empties the whole selection (all variants, whenever there is a
     * value). It is a pointer affordance (`tabindex="-1"`); keyboard users clear from an empty
     * query — Backspace removes the last chip in multi-select (repeat to empty it), and
     * Backspace/Delete clears a single selection.
     */
    clearable?: boolean;
    /** Fully disables the control: not focusable, cannot open, cannot mutate. */
    disabled?: boolean;
    /** Locks the value: focusable and readable, but cannot open, edit, or mutate. */
    readonly?: boolean;
    /**
     * Debounce the list source between re-filters: `true` uses the shared input delay, a number
     * sets the milliseconds, `false` is instant. Defaults to whether the source is server-backed,
     * so a client source never flashes a loading skeleton while an async one is throttled.
     */
    debounce?: boolean | number;
    /**
     * Minimum query length before the list searches. A query shorter than this — including the
     * empty query on open — shows a keep-typing hint and issues no source call (no request, no
     * skeleton). `0` (default) searches on any input.
     */
    minChars?: number;
    /** The overlay's preferred placement relative to the trigger (forwarded to the menu). */
    placement?: MenuOptions["placement"];
    /** The overlay's offset from the trigger, in pixels (forwarded to the menu). */
    offset?: MenuOptions["offset"];
    /** Called when the overlay opens; composed with the internal open handling. */
    onShow?: () => void;
    /** Called when the overlay closes; composed with the internal close handling. */
    onClose?: () => void;
  };
  Element: HTMLElement;
  Blocks: {
    item?: [SelectItemModel];
    selection?: [SelectItemModel];
    /** Consumer override for the no-results state, replacing the default "No results found". */
    empty?: [];
  };
}

/**
 * A single- or multi-select combobox built on the headless {@link SelectEngine}. It composes the
 * sanctioned foundations — `DMenu` (overlay + mobile modal), `DAsyncContent` (loading /
 * empty / error, on either a client or a server source), `dRovingFocus` (WAI-ARIA combobox
 * keyboard), and `DSkeleton` (loading) — and wires screen-reader announcements through the
 * `a11y` service.
 *
 * The trigger style is chosen with `@variant` (default `typeahead`):
 * - `typeahead` — single-select renders the trigger as a `role="combobox"` input; multi-select
 *   renders chips alongside that input. A bare id resolves through `DAsyncContent` without
 *   flashing the id; on mobile the input moves into the modal.
 * - `button` — a button trigger with the filter input inside the panel.
 * - `static` — a short, unsearchable list whose listbox takes focus (the native-`<select>`
 *   replacement).
 *
 * Consumers pass a data source (`@items` or `@load`) and can override the label-field
 * fallback with `:item` and `:selection` blocks. Everything else — filtering, async state,
 * keyboard, ARIA, positioning, mobile — is handled. Presets wrap this with a domain source
 * and row markup.
 */
export default class DSelect extends Component<DSelectSignature> {
  @service declare a11y: A11y;
  @service declare menu: Menu;

  /**
   * The filter input element, handed to `dRovingFocus` as the combobox controller
   * (keydown binds to it; `aria-activedescendant` is written on it). In `typeahead` it is
   * the trigger input; in `button` it is the in-panel filter.
   */
  @tracked filterInput: HTMLElement | null = null;

  /** The listbox element, which is the reveal sentinel's intersection root. */
  @tracked listboxElement: HTMLElement | null = null;

  /** Whether a server load has run long enough to deserve a visible placeholder. */
  @tracked loadFeedbackDue = false;

  @tracked queryActive = false;

  @tracked isExpanded = false;

  /**
   * Empty `@untriggers` for `typeahead`: keeps DMenu's default click-to-open on the whole
   * trigger while disabling close-on-click, so clicking the open trigger/input doesn't
   * toggle it shut (see template).
   */
  emptyTriggers: string[] = [];

  // Constructed once from the (stable) args; never exposed to consumers — internal
  // parts receive it but touch only its public API.
  engine = new SelectEngine({
    // Read lazily so the engine reflects the parent's (reactive) @value — controlled.
    getValue: () => this.args.value,
    multiple: this.args.multiple,
    identifiers: this.args.identifiers ?? this.args.identifier,
    minChars: this.args.minChars,
    items: this.args.items,
    load: this.args.load,
    filterBy: this.args.filterBy,
    valueField: this.args.valueField,
    labelField: this.args.labelField,
    selected: this.args.selected,
    resolveValue: this.args.resolveValue,
    resolveValues: this.args.resolveValues,
    allowCreate: this.args.allowCreate,
    createItem: this.args.createItem,
    createUnresolvedItem: this.args.createUnresolvedItem,
    specialItems: this.args.specialItems,
    onChange: this.handleChange,
    requestClose: () => this.#menu?.close(),
    // Handles for the `modifySelectKit` compat bridge. The element must be the trigger
    // (which stays in the host DOM) — not the panel, which the overlay portals out — so
    // legacy callbacks that walk up from it (e.g. `.closest("#reply-control")`) resolve.
    legacy: {
      owner: getOwner(this),
      // The bridge anchor must be a real host-DOM node (legacy callbacks walk up from it,
      // e.g. `.closest("#reply-control")`). `triggerElement` is the instance's trigger
      // narrowed to `HTMLElement` (null for a virtual trigger — never our case).
      getElement: () => this.#menu?.triggerElement ?? null,
      isDestroyed: () => this.isDestroying || this.isDestroyed,
    },
  });

  // The DMenu instance, captured on register so the engine can close the overlay and
  // the compat bridge can reach the trigger element.
  #menu: DMenuInstance | null = null;

  // Controls for moving focus into the multi-select chip group, registered by the
  // chips' `dRovingFocus` (desktop only). Read imperatively from the keyboard handlers,
  // so a plain field rather than tracked; `null` while unregistered (mobile / single).
  #chipRoving: DRovingFocusApi | null = null;

  #listboxId = `d-combobox-listbox-${guidFor(this)}`;

  // The last keep-typing "characters remaining" announced, so a repeat isn't re-read.
  #lastAnnouncedRemaining: number | null = null;

  // Deduping on the message rather than a count is what keeps a reveal silent: it grows the
  // mounted rows without changing the total the message reports.
  #lastAnnouncedCountMessage: string | null = null;

  // Keyed on the query, not a flag: the hint unmounts and remounts as the window grows, and
  // only a new query should re-read it.
  #narrowAnnouncedFor: string | null = null;

  // Whether a "loading more" was announced and still owes its completion.
  #revealAnnounced = false;

  #loadFeedbackTimer?: ReturnType<typeof discourseLater>;

  #suppressNextCount = false;

  // True only for the synchronous span of `focusTriggerInput`, so the query input can tell
  // an open-driven programmatic focus (which must NOT select the label) from a genuine
  // keyboard focus (Tab-in, which selects the label for replacement).
  #focusingFromOpen = false;

  /** The listbox id, wiring `aria-controls`/`aria-activedescendant`. */
  get listboxId(): string {
    return this.#listboxId;
  }

  /**
   * The listbox id to advertise on the combobox controls (`aria-controls`/`aria-owns`), or
   * `undefined` when no listbox is rendered — below `@minChars` the list is replaced by the
   * keep-typing hint, so pointing a combobox at a non-existent listbox would be a dangling
   * reference. The listbox element itself always uses {@link listboxId}.
   */
  get activeListboxId(): string | undefined {
    return this.engine.belowMinChars ? undefined : this.listboxId;
  }

  /** Stable prefix for the per-chip element ids (label + remove button). */
  get chipIdPrefix() {
    return `d-combobox-chip-${guidFor(this)}`;
  }

  /** Stable id for the query input's `aria-describedby` chip-navigation hint. */
  get chipHintId() {
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
   * Distinct-keyed placeholder rows for the loading skeleton (`@skeletonCount`,
   * default 5).
   */
  get skeletonRows(): Array<{ key: number }> {
    // Enough to fill the listbox viewport (20em against a ~2.4em row) and overflow it
    // slightly, so a clipped final placeholder reads as more content rather than a short list.
    const count = this.args.skeletonCount ?? 10;
    return Array.from({ length: count }, (_, key) => ({ key }));
  }

  /** The trigger style; defaults to `typeahead`. */
  get variant(): SelectVariant {
    return this.args.variant ?? SELECT_VARIANTS.typeahead;
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
    if (this.args.multiple) {
      classes.push("--multiple");
    }
    if (this.triggerIsControl) {
      classes.push("--control");
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

  get triggerRootHasPopup(): string | undefined {
    return this.triggerIsControl ? "listbox" : undefined;
  }

  /**
   * The accessible name for the control-variant trigger root — the `role` lives on the `<div>`,
   * so the name must too. The typeahead/multi variants name their inner `role="combobox"` input
   * instead (via `ComboboxQueryInput @label`), so the root stays unnamed there.
   */
  get triggerRootLabel(): string | undefined {
    return this.triggerIsControl ? this.ariaLabelText : undefined;
  }

  get triggerRootControls(): string | undefined {
    return this.triggerIsControl && this.isExpanded
      ? this.activeListboxId
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
    return this.args.disabled ?? false;
  }

  get isReadonly(): boolean {
    return this.args.readonly ?? false;
  }

  get isLocked(): boolean {
    return this.isDisabled || this.isReadonly;
  }

  /** The resolved caret icon for the current open/closed state. */
  get caretIcon(): string {
    const arg = this.args.caretIcon;
    if (typeof arg === "string") {
      return arg;
    }
    return this.isExpanded
      ? (arg?.open ?? "angle-up")
      : (arg?.closed ?? "angle-down");
  }

  /** Whether the clear control renders: opted in, something selected, and not locked. */
  get showClear(): boolean {
    return !!this.args.clearable && this.engine.hasValue && !this.isLocked;
  }

  /** The clear control's accessible name — `"Clear all"` for multi, `"Clear selection"` otherwise. */
  get clearLabel(): string {
    return this.args.multiple
      ? i18n("d_select.clear_all")
      : i18n("d_select.clear");
  }

  /**
   * The list debounce forwarded to `DAsyncContent`. Defaults to whether the source is
   * server-backed (`engine.isAsync`) so a client source never flashes a skeleton, while a
   * consumer can force a delay with `true`/a number or disable it with `false`.
   */
  get debounce(): boolean | number {
    return this.args.debounce ?? this.engine.isAsync;
  }

  /**
   * Whether the overlay renders as a mobile modal (an `aria-modal` dialog) rather than an
   * inline popover. Delegates to the `menu` service — the exact decision `<DMenu>` makes — so
   * the trigger's mobile/desktop behavior can never drift from what the overlay actually
   * renders. DSelect always opts into `@modalForMobile`, so it asks with `true`.
   */
  get overlayIsModal(): boolean {
    return this.menu.shouldRenderInModal(true);
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
   * Whether roving runs in `active` mode — the combobox controller keeps DOM focus and
   * `aria-activedescendant` drives the highlight — rather than `focus` mode (a roving tabindex
   * through the options). The controller is the query input for `typeahead` and the trigger
   * `<div>` for desktop `static` (a WAI-ARIA select-only combobox). Only **static in the mobile
   * modal** uses focus mode: its list lives in an `aria-modal` dialog, so DOM focus must move
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
   */
  get shouldAutoActivateFirst(): boolean {
    return this.isTypeahead || (this.isStatic && !this.overlayIsModal);
  }

  get fallbackSelectionLabel(): string {
    const resolved = this.engine.resolveSingleSync(this.args.value);
    if (resolved?.__unresolved) {
      // The plain input can't render the icon/muted treatment chips get, so the label has to
      // carry the state itself. A consumer-named fallback ("Topic #123") already reads as
      // one; only the bare-id default needs the suffix to not look like a real label.
      return this.engine.isCustomUnresolvedItem(resolved)
        ? this.engine.getItemLabel(resolved)
        : i18n("d_select.unresolved_value", { value: this.args.value });
    }
    return this.engine.getSingleSelectionLabel(this.args.value);
  }

  get labelField(): string {
    return this.args.labelField ?? "name";
  }

  get queryPlaceholder(): string {
    if (this.engine.hasValue) {
      return "";
    }
    return this.args.placeholder || i18n("d_select.add_placeholder");
  }

  /** The filter input's placeholder (the consumer's `@searchPlaceholder` or a default). */
  get searchPlaceholderText(): string {
    return this.args.searchPlaceholder ?? i18n("d_select.search_placeholder");
  }

  /** The combobox/listbox accessible name (the consumer's `@label` or a default). */
  get ariaLabelText(): string {
    return this.args.label ?? i18n("d_select.label");
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
    if (this.isStatic && !this.overlayIsModal) {
      this.filterInput = element;
    }
  }

  /**
   * Static in the mobile modal: on open, move DOM focus onto the first (or the roving-`0`)
   * option, since the list lives in an `aria-modal` dialog the out-of-modal trigger can't
   * control. A no-op for every other variant/surface, which keep focus on their controller.
   */
  @action
  focusListboxIfSimple(element: HTMLElement): void {
    if (!(this.isStatic && this.overlayIsModal)) {
      return;
    }
    const target =
      element.querySelector<HTMLElement>('[role="option"][tabindex="0"]') ??
      element.querySelector<HTMLElement>('[role="option"]');
    schedule("afterRender", () => {
      if (target?.isConnected) {
        target.focus({ preventScroll: true });
      }
    });
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
    if (this.isTypeahead) {
      this.handleMenuClose();
    }
    if (wasExpanded) {
      this.args.onClose?.();
    }
  }

  /**
   * Runs on every typeahead menu close, resetting the query so the next open starts clean.
   * Multi-select also resets on an add because its menu remains open after selection.
   */
  @action
  handleMenuClose(): void {
    this.engine.setFilter("");
    this.queryActive = false;
  }

  @action
  handleShow(): void {
    // DMenu can invoke its show hook without a real state change (clicking an already-open
    // trigger re-enters `show`), so gate the consumer callback on an actual closed→open
    // transition. The input still re-focuses on every click, which is the desired behavior.
    const wasExpanded = this.isExpanded;
    this.isExpanded = true;
    if (this.isTypeahead) {
      this.focusTriggerInput();
    }
    if (!wasExpanded) {
      this.args.onShow?.();
    }
  }

  @action
  handleTriggerRootKeydown(event: KeyboardEvent): void {
    if (
      !this.triggerIsControl ||
      this.isExpanded ||
      this.isLocked ||
      event.isComposing
    ) {
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
    // Keyboard clear for the control variants (which have no text input): Backspace/Delete on
    // the closed trigger empties the selection.
    if (
      this.args.clearable &&
      this.engine.hasValue &&
      (event.key === "Backspace" || event.key === "Delete")
    ) {
      event.preventDefault();
      this.engine.clear();
    }
  }

  /**
   * Clears the whole selection from the trigger clear control, stopping the click from toggling
   * the overlay, then returns focus to the controller (the query input, or the trigger itself).
   */
  @action
  handleClear(event: MouseEvent): void {
    event.stopPropagation();
    if (this.isLocked) {
      return;
    }
    this.engine.clear();
    (this.filterInput ?? this.#menu?.triggerElement)?.focus();
  }

  @action
  beginQuery(): void {
    this.queryActive = true;
  }

  /**
   * On open, move focus into the query input so a click anywhere on the trigger (label,
   * caret, gaps — all open the menu via DMenu's trigger-root click) lands the caret in the
   * input on desktop. Null-safe on mobile: the query input lives in the modal and self-
   * focuses via `captureFilter` once it mounts (after this runs).
   */
  @action
  focusTriggerInput(): void {
    this.#focusingFromOpen = true;
    this.filterInput?.focus();
    this.#focusingFromOpen = false;
  }

  /**
   * Whether a focus landing on the query input should select the displayed label (for
   * overtype). True for a genuine keyboard focus; false for the programmatic focus fired
   * while opening, where the caret must stay where the pointer put it.
   */
  @action
  shouldSelectOnFocus(): boolean {
    return !this.#focusingFromOpen;
  }

  /**
   * Keeps focus in the trigger input when an option is pointer-selected: preventing the
   * `mousedown` default stops the input blurring, which would otherwise close the menu
   * before the option's `click` resolves. This matters for action rows and multi-select,
   * which keep the menu open.
   */
  @action
  preventPointerBlur(event: MouseEvent): void {
    if (this.isTypeahead) {
      event.preventDefault();
    }
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
    const next = event.relatedTarget;
    if (!(next instanceof Node)) {
      return;
    }
    const trigger = this.#menu?.triggerElement;
    const content = this.#menu?.content;
    if (
      (trigger && trigger.contains(next)) ||
      (content && content.contains(next))
    ) {
      return;
    }
    this.#menu?.close();
  }

  @action
  loadListContent(
    context: unknown,
    opts?: SelectLoadOptions
  ): SelectListContent | Promise<SelectListContent> {
    const rawItems = this.engine.loadItems(context, opts);
    return rawItems instanceof Promise
      ? rawItems.then((items) => ({ rawItems: items }))
      : { rawItems };
  }

  /**
   * Resolves the single bound value to its one display item for the trigger
   * `DAsyncContent`. Narrows the engine's arity-union return to the single form; a `null`
   * value returns `undefined` (routed to `:empty`), while a held value that can't resolve
   * comes back as an `__unresolved` fallback item rather than `undefined`.
   */
  @action
  resolveSingle(
    value: unknown,
    opts?: SelectLoadOptions
  ): SelectItemModel | Promise<SelectItemModel> {
    return this.engine.resolveSelection(value as SelectValue, opts) as
      | SelectItemModel
      | Promise<SelectItemModel>;
  }

  /**
   * Resolves the bound ids to chip descriptors for the multi trigger. Narrows to the
   * array form; an empty value returns `undefined` (→ `:empty`). Uncached ids resolve in a
   * single batch, and any id that can't resolve becomes an `__unresolved` fallback chip
   * (never a hole). Normalizing to descriptors here (not in the template) means the chips
   * are built once per value change and stay referentially stable across re-renders.
   */
  @action
  resolveMulti(
    value: unknown,
    opts?: SelectLoadOptions
  ):
    | readonly SelectDescriptor[]
    | Promise<readonly SelectDescriptor[]>
    | undefined {
    const resolved = this.engine.resolveSelection(value as SelectValue, opts);
    if (resolved == null) {
      return undefined;
    }
    if (resolved instanceof Promise) {
      return resolved.then((items) =>
        this.engine.describeItems(items as SelectItemModel[])
      );
    }
    return this.engine.describeItems(resolved as SelectItemModel[]);
  }

  @action
  onFilterInput(event: Event): void {
    this.engine.setFilter((event.target as HTMLInputElement).value);
  }

  @action
  handleInputKeydown(event: KeyboardEvent): void {
    const input = event.target as HTMLInputElement;

    // Removing from the selection on an empty query: multi drops the last chip on Backspace
    // (repeat to empty it) — Backspace is the token-input convention, deleting backward toward
    // the chip before the caret; single clears on Backspace/Delete when `@clearable`, since a
    // lone value isn't a directional token. Blocked while locked.
    if (
      !event.isComposing &&
      input.value === "" &&
      this.engine.hasValue &&
      !this.isLocked
    ) {
      if (this.args.multiple && event.key === "Backspace") {
        event.preventDefault();
        this.engine.deselectLast();
        return;
      }
      if (
        !this.args.multiple &&
        this.args.clearable &&
        (event.key === "Backspace" || event.key === "Delete")
      ) {
        event.preventDefault();
        this.engine.clear();
        return;
      }
    }

    // Desktop multi: ArrowLeft at the very start of the query moves focus into the chip
    // group (the chip nearest the input). Only the desktop trigger hosts the chips inline;
    // the mobile input lives in the modal, so entering the trigger chips would break out of
    // it. `preventDefault` only when a chip actually took focus, so an empty control (or a
    // loading re-flash) leaves ArrowLeft as a plain no-op caret move.
    if (
      this.isDesktopTypeahead &&
      event.key === "ArrowLeft" &&
      !event.isComposing &&
      input.selectionStart === 0 &&
      input.selectionEnd === 0 &&
      this.engine.hasValue &&
      this.#chipRoving?.focusLast()
    ) {
      event.preventDefault();
    }
  }

  /**
   * `dRovingFocus` hands `onActivate` the active option element; clicking it runs the
   * same handler as a pointer click, so keyboard and pointer share one selection path.
   */
  @action
  activateElement(element: HTMLElement): void {
    element.click();
  }

  /**
   * Politely announces the result count to screen readers via the shared `a11y`
   * service (never a per-component live region, never assertive), skipping repeats.
   *
   * Reports the true total when the source can supply one, not how many rows happen to be
   * mounted, so a 5000-result query does not announce "50 results". A source with no total
   * announces the loaded count instead.
   */
  @action
  announceCount(
    _element: HTMLElement,
    [rendered, total]: [number, number | undefined]
  ): void {
    // Mid-load the rows on screen are the previous query's and the total is already cleared,
    // so any count now describes stale rows. Settling re-fires this with the real numbers.
    if (this.engine.serverPending) {
      return;
    }

    const message =
      total == null
        ? i18n("d_select.results_loaded", { count: rendered })
        : i18n("d_select.results_count", { count: total });

    if (this.#suppressNextCount) {
      this.#suppressNextCount = false;
      // Record the suppressed message as last-known, or a later genuine search that lands on
      // the same count would be treated as a repeat and never announced.
      this.#lastAnnouncedCountMessage = message;
      return;
    }
    if (message === this.#lastAnnouncedCountMessage) {
      return;
    }
    this.#lastAnnouncedCountMessage = message;
    this.a11y.announce(message, "polite");
  }

  /**
   * A freshly mounted listbox is a fresh context, so the count always announces on open even
   * when it matches what the previous open announced. Updates while the list stays mounted
   * keep deduping through {@link announceCount}.
   */
  @action
  announceCountOnEntry(
    element: HTMLElement,
    args: [number, number | undefined]
  ): void {
    this.#lastAnnouncedCountMessage = null;
    this.announceCount(element, args);
  }

  /** Placeholders stand in for a pending page, appended after the rows already shown. */
  get showRevealPlaceholder(): boolean {
    return this.loadFeedbackDue && this.engine.serverRevealPending;
  }

  /**
   * Placeholders replace the list outright, because a re-query's retained rows are answers to
   * the previous query and the new ones arrive at the top, where the user is looking.
   */
  get showQueryPlaceholder(): boolean {
    return (
      this.loadFeedbackDue &&
      this.engine.serverPending &&
      !this.engine.serverRevealPending
    );
  }

  /**
   * Arms the placeholder only once a load has been pending past the threshold, so a source
   * that answers quickly shows nothing at all.
   */
  @action
  trackLoadFeedback(_element: HTMLElement, [pending]: [boolean]): void {
    cancel(this.#loadFeedbackTimer);
    if (!pending) {
      this.loadFeedbackDue = false;
      return;
    }
    this.#loadFeedbackTimer = discourseLater(
      this,
      () => (this.loadFeedbackDue = true),
      LOADING_FEEDBACK_DELAY
    );
  }

  /** Captures the listbox so the reveal sentinel can be rooted at its scroll container. */
  @action
  captureListbox(element: HTMLElement): void {
    this.listboxElement = element;
  }

  /**
   * Drops the listbox ref on unmount. Kept stale, it would root a reopened list's observer at
   * a detached node, which never intersects, and the list could never be revealed again.
   */
  @action
  releaseListbox(): void {
    this.listboxElement = null;
    cancel(this.#loadFeedbackTimer);
    this.loadFeedbackDue = false;
  }

  /**
   * Politely reports a server reveal, which is otherwise silent: the rows stay put while the
   * next page is in flight, so nothing visibly changes until it lands.
   */
  @action
  announceReveal(): void {
    // A new query is also pending and also retains its rows, but it is not more results — its
    // own count announcement covers it when it lands.
    if (this.engine.serverRevealPending) {
      this.#revealAnnounced = true;
      this.a11y.announce(i18n("d_select.loading_more"), "polite");
      return;
    }

    if (this.#revealAnnounced && !this.engine.serverPending) {
      this.#revealAnnounced = false;
      this.a11y.announce(i18n("d_select.loading_complete"), "polite");
    }
  }

  /**
   * Announces the keep-filtering hint once per query. The visible status node stays for
   * sighted users; a live region announces unreliably on the render that mounts it.
   */
  @action
  announceNarrow(): void {
    const filter = this.engine.filter;
    if (filter === this.#narrowAnnouncedFor) {
      return;
    }
    this.#narrowAnnouncedFor = filter;
    // Longer than the default window: the cap is typically reached while scrolling, when a
    // screen reader is still voicing option changes and would miss a short-lived message.
    this.a11y.announce(i18n("d_select.filter_to_narrow"), "polite", 5000);
  }

  /**
   * Politely announces the keep-typing hint as the query grows below `@minChars`. Routed through
   * the shared `a11y` service (like the count) rather than the visible `role="status"` node,
   * which a freshly-mounted live region announces unreliably. Deduped on the remaining count.
   */
  @action
  announceMinChars(_element: HTMLElement, [remaining]: [number]): void {
    if (remaining === this.#lastAnnouncedRemaining) {
      return;
    }
    this.#lastAnnouncedRemaining = remaining;
    this.a11y.announce(
      i18n("d_select.min_chars", { count: remaining }),
      "polite"
    );
  }

  /**
   * A fresh entry into the below-threshold state (the hint mounting) always announces, even when
   * the remaining count matches what was last announced before the user briefly rose above the
   * threshold — otherwise re-entering the same partial query would stay silent. Updates while the
   * hint stays mounted keep deduping through {@link announceMinChars}.
   */
  @action
  announceMinCharsOnEntry(element: HTMLElement, args: [number]): void {
    this.#lastAnnouncedRemaining = null;
    this.announceMinChars(element, args);
  }

  @action
  handleChange(
    nextValue: SelectValue,
    payload: SelectItemModel | SelectItemModel[] | null
  ): void {
    if (this.args.multiple) {
      // This must be read before forwarding because the parent applies nextValue synchronously.
      const oldValues = makeArray(this.args.value);
      const nextValues = makeArray(nextValue);
      const oldKeys = new Set(oldValues.map(String));
      const nextKeys = new Set(nextValues.map(String));
      const added = nextValues.find((value) => !oldKeys.has(String(value)));
      const removed = oldValues.find((value) => !nextKeys.has(String(value)));

      if (added !== undefined) {
        const item = this.engine.resolveSingleSync(added);
        this.a11y.announce(
          i18n("d_select.item_added", {
            item: item ? this.engine.getItemLabel(item) : String(added),
          }),
          "polite"
        );
        if (this.engine.filter !== "") {
          this.#suppressNextCount = true;
          this.engine.setFilter("");
          this.queryActive = false;
          nextRunloop(() => (this.#suppressNextCount = false));
        }
      } else if (removed !== undefined) {
        const item = this.engine.resolveSingleSync(removed);
        this.a11y.announce(
          i18n("d_select.item_removed", {
            item: item ? this.engine.getItemLabel(item) : String(removed),
          }),
          "polite"
        );
      }
    }
    this.args.onChange?.(nextValue, payload);
  }

  /**
   * Removes a chip's item, stops the click from opening the menu, and restores input focus
   * after the focused remove button unmounts. Handles a pointer click and the button's
   * native Enter/Space activation; Backspace/Delete go through `handleChipKeydown`.
   */
  @action
  removeItem(item: SelectItemModel, event?: MouseEvent): void {
    event?.stopPropagation();
    if (this.isLocked) {
      return;
    }
    this.engine.deselect(item);
    this.filterInput?.focus();
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
      this.filterInput?.focus();
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
    item: SelectItemModel,
    index: number,
    event: KeyboardEvent
  ): void {
    if (!this.isDesktopTypeahead) {
      return;
    }

    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault();
      this.filterInput?.focus();
      if (!this.isLocked) {
        this.#menu?.show();
      }
      return;
    }

    if (this.isLocked) {
      return;
    }

    if (event.key === "Backspace" || event.key === "Delete") {
      event.preventDefault();
      event.stopPropagation();
      this.engine.deselect(item);
      // The chip DOM re-renders on the value change; restore focus once it settles. A
      // macrotask lands after the render flush, and the boolean guard falls back to the
      // input if the group is momentarily empty.
      nextRunloop(() => {
        const remaining = makeArray(this.args.value).length;
        if (
          remaining > 0 &&
          this.#chipRoving?.focusIndex(Math.max(0, index - 1))
        ) {
          return;
        }
        this.filterInput?.focus();
      });
    }
  }

  <template>
    <DMenu
      @identifier={{@identifier}}
      @modalForMobile={{true}}
      @matchTriggerWidth={{true}}
      @placement={{@placement}}
      @offset={{@offset}}
      @contentClass="d-combobox__content"
      @trapTab={{false}}
      {{! Typeahead: keep DMenu's default click-to-open (the whole trigger root opens the
        overlay) but disable close-on-click so clicking the already-open trigger/input does
        not toggle it shut. Reset the query on every close; focus the input on open. }}
      @untriggers={{if this.isTypeahead this.emptyTriggers}}
      {{! DMenu vetoes its own trigger open while locked, reactively. Keyboard/edit open + all
        mutate paths are gated separately in this component (they are not DMenu listeners). }}
      @disabled={{this.isLocked}}
      @onClose={{this.handleClose}}
      @onShow={{this.handleShow}}
      @onRegisterApi={{this.registerMenu}}
      @triggerClass={{this.triggerClass}}
      {{! Control variants put ARIA and keyboard behavior on the root; input variants put
        them on their inner input. }}
      @triggerComponent={{dElement "div"}}
      role={{this.triggerRootRole}}
      tabindex={{this.triggerRootTabIndex}}
      aria-label={{this.triggerRootLabel}}
      aria-haspopup={{this.triggerRootHasPopup}}
      aria-controls={{this.triggerRootControls}}
      aria-disabled={{this.triggerRootDisabled}}
      aria-readonly={{this.triggerRootReadonly}}
      {{on "keydown" this.handleTriggerRootKeydown}}
      {{didInsert this.registerStaticController}}
      class="d-combobox"
      ...attributes
    >
      <:trigger as |menuArgs|>
        {{! Resolve the raw @value (stable identity) rather than engine.value, so this
          async context does not churn each render; a content-only skeleton shows while
          it resolves, so a bare id never flashes. }}
        <TriggerFrame
          @icon={{@icon}}
          @caret={{this.caretIcon}}
          @showClear={{this.showClear}}
          @clearLabel={{this.clearLabel}}
          @onClear={{this.handleClear}}
        >
          {{#if @multiple}}
            {{! Desktop multi: the chips are a horizontal arrow-roving group whose remove buttons
            are the navigable items (`tabindex=-1` below), so the query input stays the sole tab
            stop. Gated to desktop — the mobile trigger has no inline input to enter the chips
            from (Mobile M5 is separate). }}
            {{! The chips are a real list (ul/li) so assistive tech announces them as a
            navigable collection; display:contents keeps the items flowing inline with the
            query input, which is a sibling of the list (an input cannot be a child of a ul). }}
            <div class="d-combobox__chips">
              <ul
                class="d-combobox__chip-list"
                aria-label={{i18n "d_select.selected_items"}}
                {{(if
                  this.isDesktopTypeahead
                  (modifier
                    dRovingFocus
                    tabStop=false
                    orientation="horizontal"
                    itemSelector=".d-combobox__chip-remove"
                    onExit=this.exitChipsToInput
                    onRegisterApi=this.registerChipRoving
                  )
                )}}
              >
                <DAsyncContent
                  @asyncData={{this.resolveMulti}}
                  @context={{@value}}
                >
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
                          {{#if (has-block "selection")}}
                            {{yield chip.item to="selection"}}
                          {{else}}
                            <SelectionLabel
                              @item={{chip.item}}
                              @labelField={{this.labelField}}
                            />
                          {{/if}}
                        </span>
                        <button
                          type="button"
                          class="d-combobox__chip-remove"
                          disabled={{this.isLocked}}
                          {{! Desktop: never a tab stop — reached by arrow-roving from the input.
                        A static -1 keeps every newly-rendered chip out of the tab order with
                        no dependence on the modifier re-seeding. Mobile keeps native tab stops. }}
                          tabindex={{if this.isDesktopTypeahead "-1"}}
                          {{! Name leads with the item, then how to remove it (e.g. "Orange, Press
                          Backspace or Delete to remove") so it reads as a selected item rather
                          than a bare action. }}
                          aria-labelledby="{{this.chipIdPrefix}}-{{index}}-label {{this.chipIdPrefix}}-{{index}}-remove"
                          {{on "click" (fn this.removeItem chip.item)}}
                          {{on
                            "keydown"
                            (fn this.handleChipKeydown chip.item index)
                          }}
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
              {{#if this.isDesktopTypeahead}}
                <ComboboxQueryInput
                  @engine={{this.engine}}
                  @listboxId={{this.activeListboxId}}
                  @expanded={{menuArgs.expanded}}
                  @label={{this.ariaLabelText}}
                  @displayValue=""
                  @placeholder={{this.queryPlaceholder}}
                  @editing={{this.queryActive}}
                  @ariaOwns={{true}}
                  @shouldSelectOnFocus={{this.shouldSelectOnFocus}}
                  @onOpen={{menuArgs.show}}
                  @onRequestClose={{menuArgs.close}}
                  @onBlur={{this.handleTriggerBlur}}
                  @onEdit={{this.beginQuery}}
                  @registerInput={{this.registerTriggerInput}}
                  @disabled={{this.isDisabled}}
                  @readonly={{this.isReadonly}}
                  aria-describedby={{if this.engine.hasValue this.chipHintId}}
                  {{on "keydown" this.handleInputKeydown}}
                />
                {{#if this.engine.hasValue}}
                  <span id={{this.chipHintId}} class="sr-only">
                    {{i18n "d_select.chips_hint"}}
                  </span>
                {{/if}}
              {{/if}}
            </div>
          {{else if this.isTypeahead}}
            {{! Composite box: [selection presentation] · [query input] · [caret]. The input
            displays either the selected-label fallback or the query; custom selection markup
            is a sibling, hidden from the first edit until close. A click anywhere on the
            trigger opens the overlay (DMenu's trigger-root click; onShow focuses the input).
            On mobile the query input lives in the modal (below), so tapping the trigger opens
            it there. }}
            {{#unless this.queryActive}}
              {{#if this.isMobileTypeahead}}
                <span class="d-combobox__presentation">
                  {{#if this.engine.hasValue}}
                    <DAsyncContent
                      @asyncData={{this.resolveSingle}}
                      @context={{@value}}
                    >
                      <:loading><DSkeleton
                          @variant="text"
                          @width="8ch"
                        /></:loading>
                      <:content as |selected|>
                        {{#if (has-block "selection")}}
                          {{yield selected to="selection"}}
                        {{else}}
                          <SelectionLabel
                            @item={{selected}}
                            @labelField={{this.labelField}}
                          />
                        {{/if}}
                      </:content>
                    </DAsyncContent>
                  {{else}}
                    <span class="d-combobox__placeholder">
                      {{or @placeholder (i18n "d_select.placeholder")}}
                    </span>
                  {{/if}}
                </span>
              {{else if (has-block "selection")}}
                {{#if this.engine.hasValue}}
                  <span class="d-combobox__presentation">
                    <DAsyncContent
                      @asyncData={{this.resolveSingle}}
                      @context={{@value}}
                    >
                      <:loading><DSkeleton
                          @variant="text"
                          @width="8ch"
                        /></:loading>
                      <:content as |selected|>{{yield
                          selected
                          to="selection"
                        }}</:content>
                    </DAsyncContent>
                  </span>
                {{/if}}
              {{else if this.engine.hasValue}}
                <DAsyncContent
                  @asyncData={{this.resolveSingle}}
                  @context={{@value}}
                >
                  <:loading>
                    <span class="d-combobox__presentation">
                      <DSkeleton @variant="text" @width="8ch" />
                    </span>
                  </:loading>
                  <:content></:content>
                </DAsyncContent>
              {{/if}}
            {{/unless}}
            {{#if this.isDesktopTypeahead}}
              <ComboboxQueryInput
                @engine={{this.engine}}
                @listboxId={{this.activeListboxId}}
                @expanded={{menuArgs.expanded}}
                @label={{this.ariaLabelText}}
                {{! No placeholder once a value is chosen: the value is shown either in this input
                  (default) or in the sibling selection presentation (with a `:selection` block),
                  so a placeholder would otherwise sit next to it. }}
                @placeholder={{unless
                  this.engine.hasValue
                  (or @placeholder (i18n "d_select.placeholder"))
                }}
                @displayValue={{if
                  (has-block "selection")
                  ""
                  this.fallbackSelectionLabel
                }}
                @editing={{this.queryActive}}
                @ariaOwns={{true}}
                @shouldSelectOnFocus={{this.shouldSelectOnFocus}}
                @onOpen={{menuArgs.show}}
                @onRequestClose={{menuArgs.close}}
                @onBlur={{this.handleTriggerBlur}}
                @onEdit={{this.beginQuery}}
                @registerInput={{this.registerTriggerInput}}
                @disabled={{this.isDisabled}}
                @readonly={{this.isReadonly}}
                {{on "keydown" this.handleInputKeydown}}
              />
            {{/if}}
          {{else}}
            <DAsyncContent
              @asyncData={{this.resolveSingle}}
              @context={{@value}}
            >
              <:loading><DSkeleton @variant="text" @width="8ch" /></:loading>
              <:content as |selected|>
                <span class="d-combobox__value">
                  {{#if (has-block "selection")}}
                    {{yield selected to="selection"}}
                  {{else}}
                    <SelectionLabel
                      @item={{selected}}
                      @labelField={{this.labelField}}
                    />
                  {{/if}}
                </span>
              </:content>
              <:empty>
                <span class="d-combobox__placeholder">
                  {{or @placeholder (i18n "d_select.placeholder")}}
                </span>
              </:empty>
            </DAsyncContent>
          {{/if}}
        </TriggerFrame>
      </:trigger>

      <:content as |menuArgs|>
        <div class="d-combobox__panel">
          {{#if this.isPanelSearchable}}
            <DFilterInput
              class="d-combobox__filter"
              role="combobox"
              aria-expanded="true"
              aria-controls={{this.activeListboxId}}
              aria-autocomplete="list"
              autocomplete="off"
              placeholder={{this.searchPlaceholderText}}
              @value={{this.engine.filter}}
              @filterAction={{this.onFilterInput}}
              @icons={{hash left="magnifying-glass"}}
              {{didInsert this.captureFilter}}
            />
          {{else if this.isMobileTypeahead}}
            {{! Mobile: the query input lives inside the modal (an external host input can't
              function behind an aria-modal). No aria-owns (input + listbox share the modal
              subtree); no blur-close (the modal owns dismissal). }}
            <ComboboxQueryInput
              class="d-combobox__filter"
              @engine={{this.engine}}
              @listboxId={{this.activeListboxId}}
              @expanded={{menuArgs.expanded}}
              @label={{this.ariaLabelText}}
              @placeholder={{this.searchPlaceholderText}}
              @onOpen={{menuArgs.show}}
              @onRequestClose={{menuArgs.close}}
              @editing={{this.queryActive}}
              @onEdit={{this.beginQuery}}
              @registerInput={{this.captureFilter}}
              @disabled={{this.isDisabled}}
              @readonly={{this.isReadonly}}
              {{on "keydown" this.handleInputKeydown}}
            />
          {{/if}}

          {{#if this.engine.belowMinChars}}
            {{! Below the minimum query length: no source call (no request, no skeleton flash),
              and the truthy-`[]` routing / stray create-row are sidestepped by not rendering the
              list at all. The hint is announced through the a11y service (see announceMinChars);
              the visible node stays a status region for sighted users. }}
            <div
              class="d-combobox__min-chars"
              role="status"
              {{didInsert
                this.announceMinCharsOnEntry
                this.engine.remainingMinChars
              }}
              {{didUpdate this.announceMinChars this.engine.remainingMinChars}}
            >
              {{i18n "d_select.min_chars" count=this.engine.remainingMinChars}}
            </div>
          {{else}}
            <DAsyncContent
              @asyncData={{this.loadListContent}}
              @context={{this.engine.loadContext}}
              @debounce={{this.debounce}}
              @retainWhileReloading={{true}}
            >
              <:loading>
                <ul class="d-combobox__listbox" aria-busy="true">
                  {{#each this.skeletonRows key="key" as |row|}}
                    <li class="d-combobox__skeleton" data-key={{row.key}}>
                      <DSkeleton @variant="text" />
                    </li>
                  {{/each}}
                </ul>
              </:loading>

              <:content as |content|>
                {{#let (this.engine.buildItems content.rawItems) as |items|}}
                  {{#if items.length}}
                    <ul
                      class="d-combobox__listbox"
                      role="listbox"
                      id={{this.listboxId}}
                      aria-label={{or @label (i18n "d_select.label")}}
                      aria-multiselectable={{booleanString @multiple}}
                      {{! A reveal or re-query keeps its rows mounted, so there is no skeleton
                    to show for it and the listbox reports the fetch itself. }}
                      aria-busy={{booleanString
                        this.engine.serverPending
                        omitFalse=false
                      }}
                      {{didInsert this.captureListbox}}
                      {{willDestroy this.releaseListbox}}
                      {{didInsert
                        this.announceCountOnEntry
                        items.length
                        this.engine.total
                      }}
                      {{didUpdate
                        this.announceCount
                        items.length
                        this.engine.total
                      }}
                      {{didUpdate
                        this.announceReveal
                        this.engine.serverPending
                      }}
                      {{didInsert
                        this.trackLoadFeedback
                        this.engine.serverPending
                      }}
                      {{didUpdate
                        this.trackLoadFeedback
                        this.engine.serverPending
                      }}
                      {{! Static in the mobile modal moves DOM focus into the listbox; every other
                    surface keeps focus on its controller (no-op there). }}
                      {{didInsert this.focusListboxIfSimple}}
                      {{! `active` mode: the controller (query input, or the desktop-static trigger
                    div) keeps focus and drives the highlight via aria-activedescendant. Static
                    in the mobile modal uses `focus` mode (roving tabindex through the options),
                    since its out-of-modal trigger can't be the controller. Typeahead and
                    desktop static auto-highlight the first option; re-seed when async lands. }}
                      {{dRovingFocus
                        selectionMode=(if
                          this.usesActiveRoving "active" "focus"
                        )
                        controllerElement=(if
                          this.usesActiveRoving this.filterInput
                        )
                        itemSelector="[role=option]"
                        itemsKey=(if this.isTypeahead items this.engine.filter)
                        activeClass="--active"
                        onActivate=this.activateElement
                        autoActivateFirst=this.shouldAutoActivateFirst
                      }}
                    >
                      {{#if this.showQueryPlaceholder}}
                        {{#each this.skeletonRows key="key" as |row|}}
                          <li
                            class="d-combobox__skeleton"
                            role="presentation"
                            aria-hidden="true"
                            data-key={{row.key}}
                          >
                            <DSkeleton @variant="text" />
                          </li>
                        {{/each}}
                      {{else}}
                        {{#each items key="key" as |descriptor|}}
                          <SelectItem
                            @descriptor={{descriptor}}
                            @engine={{this.engine}}
                            @multiple={{@multiple}}
                            @selectedIcon={{@selectedIcon}}
                            @locked={{this.isLocked}}
                            aria-posinset={{descriptor.posInSet}}
                            aria-setsize={{descriptor.setSize}}
                            {{! Keep focus in the trigger input on pointer-select so the input
                        doesn't blur-close the menu before the click resolves (needed for
                        action rows, which keep the menu open). mousedown is required —
                        blur fires before click; the handler no-ops for non-typeahead. }}
                            {{! eslint-disable-next-line ember/template-no-pointer-down-event-binding }}
                            {{on "mousedown" this.preventPointerBlur}}
                          >
                            {{#if (has-block "item")}}
                              {{yield descriptor.item to="item"}}
                            {{else}}
                              {{selectItemLabel
                                descriptor.item
                                this.labelField
                              }}
                            {{/if}}
                          </SelectItem>
                        {{/each}}

                        {{#if this.showRevealPlaceholder}}
                          {{! The rows are retained across a fetch, so without a placeholder the
                      list simply stops with no sighted feedback; aria-busy covers only
                      assistive tech. Hidden and role-free so the option set is unchanged. }}
                          {{#each this.skeletonRows key="key" as |row|}}
                            <li
                              class="d-combobox__skeleton"
                              role="presentation"
                              aria-hidden="true"
                              data-key={{row.key}}
                            >
                              <DSkeleton @variant="text" />
                            </li>
                          {{/each}}
                        {{else if
                          (and this.listboxElement this.engine.canRevealMore)
                        }}
                          {{! The list-item wrapper is structural: DLoadMore renders a plain
                      div, which is invalid as a direct child of a list, and the presentation
                      role keeps it out of the option set dRovingFocus queries.

                      Gated on the captured listbox because the observer roots at the scroll
                      container; mounting before that ref lands would root it at the viewport,
                      which the sentinel already intersects, firing an unasked-for reveal. }}
                          <li
                            class="d-combobox__sentinel"
                            role="presentation"
                            aria-hidden="true"
                          >
                            <DLoadMore
                              @action={{this.engine.revealMore}}
                              @enabled={{this.engine.canRevealMore}}
                              @root={{this.listboxElement}}
                              @rootMargin="200px"
                            />
                          </li>
                        {{/if}}
                      {{/if}}
                    </ul>

                    {{#if this.engine.atCapWithMore}}
                      {{! Sits outside the listbox, which admits only list items. The text also
                    goes through the a11y service because a live region announces unreliably on
                    the render that mounts it. }}
                      <div
                        class="d-combobox__narrow"
                        role="status"
                        {{didInsert this.announceNarrow}}
                      >
                        {{i18n "d_select.filter_to_narrow"}}
                      </div>
                    {{/if}}
                  {{else}}
                    <div class="d-combobox__empty" role="status">
                      {{#if (has-block "empty")}}
                        {{yield to="empty"}}
                      {{else}}
                        {{or @noResultsLabel (i18n "d_select.no_results")}}
                      {{/if}}
                    </div>
                  {{/if}}
                {{/let}}
              </:content>

              <:error as |error InlineError|>
                <div class="d-combobox__error">
                  <InlineError />
                  <DButton
                    class="d-combobox__retry btn-default"
                    @action={{this.engine.reload}}
                    @label="d_select.retry"
                  />
                </div>
              </:error>
            </DAsyncContent>
          {{/if}}
        </div>
      </:content>
    </DMenu>
  </template>
}
