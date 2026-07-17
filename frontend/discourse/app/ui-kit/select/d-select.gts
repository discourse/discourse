import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import { getOwner } from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { next as nextRunloop } from "@ember/runloop";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import type DMenuInstance from "discourse/float-kit/lib/d-menu-instance";
import booleanString from "discourse/helpers/boolean-string";
import { makeArray } from "discourse/lib/helpers";
import type Site from "discourse/models/site";
import type A11y from "discourse/services/a11y";
import { or } from "discourse/truth-helpers";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DButton from "discourse/ui-kit/d-button";
import DFilterInput from "discourse/ui-kit/d-filter-input";
import DSkeleton from "discourse/ui-kit/d-skeleton";
import dElement from "discourse/ui-kit/helpers/d-element";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dRovingFocus, {
  type DRovingFocusApi,
} from "discourse/ui-kit/modifiers/d-roving-focus";
import ComboboxQueryInput from "discourse/ui-kit/select/-internals/combobox-query-input";
import SelectItem from "discourse/ui-kit/select/-internals/select-item";
import SelectionLabel from "discourse/ui-kit/select/-internals/selection-label";
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
export type SelectVariant =
  (typeof SELECT_VARIANTS)[keyof typeof SELECT_VARIANTS];

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
  };
  Element: HTMLElement;
  Blocks: {
    item?: [SelectItemModel];
    selection?: [SelectItemModel];
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
  @service declare site: Site;

  /**
   * The filter input element, handed to `dRovingFocus` as the combobox controller
   * (keydown binds to it; `aria-activedescendant` is written on it). In `typeahead` it is
   * the trigger input; in `button` it is the in-panel filter.
   */
  @tracked filterInput: HTMLElement | null = null;

  @tracked queryActive = false;

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

  // The last count announced, so rapid re-filters that don't change the count don't spam
  // the screen reader (and don't compete with the moving `aria-activedescendant`).
  #lastAnnouncedCount: number | null = null;

  #suppressNextCount = false;

  // True only for the synchronous span of `focusTriggerInput`, so the query input can tell
  // an open-driven programmatic focus (which must NOT select the label) from a genuine
  // keyboard focus (Tab-in, which selects the label for replacement).
  #focusingFromOpen = false;

  /** The listbox id, wiring `aria-controls`/`aria-activedescendant`. */
  get listboxId(): string {
    return this.#listboxId;
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
    const count = this.args.skeletonCount ?? 5;
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
    return classes.join(" ");
  }

  /** Static/simple mode: a short unsearchable list; the listbox takes focus. */
  get isStatic(): boolean {
    return this.variant === SELECT_VARIANTS.static;
  }

  /** Whether the search input lives in the panel rather than the trigger or nowhere. */
  get isPanelSearchable(): boolean {
    return !this.isTypeahead && !this.isStatic;
  }

  /**
   * Whether roving runs in `active` mode (a text input keeps focus, `aria-activedescendant`
   * drives the highlight) rather than `focus` mode (roving tabindex through the options).
   * Every variant except `static` has an input controller.
   */
  get usesActiveRoving(): boolean {
    return !this.isStatic;
  }

  /** Desktop typeahead: the query input lives in the trigger (host DOM). */
  get isDesktopTypeahead(): boolean {
    return this.isTypeahead && !this.site.mobileView;
  }

  /** Mobile typeahead: the query input lives inside the modal (the trigger only shows the value). */
  get isMobileTypeahead(): boolean {
    return this.isTypeahead && this.site.mobileView;
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
   * Captures the desktop typeahead trigger input as the roving controller WITHOUT focusing
   * it — the trigger input is always present (not opened-into like the panel/modal input),
   * so focusing on insert would steal focus on page load.
   */
  @action
  registerTriggerInput(element: HTMLElement): void {
    this.filterInput = element;
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
   * which keep the menu open. Typeahead only — `static` options must take real
   * focus, so the guard is a no-op there (the handler is attached to every option).
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
   * loss with a null relatedTarget and no accompanying pointerdown — Tab into browser
   * chrome, a programmatic blur — won't close here; rare and accepted.)
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

    if (
      event.key === "Backspace" &&
      !event.isComposing &&
      input.value === "" &&
      this.engine.hasValue
    ) {
      event.preventDefault();
      this.engine.deselectLast();
      return;
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
   * service (never a per-component live region, never assertive), skipping repeats of the
   * same count.
   */
  @action
  announceCount(_element: HTMLElement, [count]: [number]): void {
    if (this.#suppressNextCount) {
      this.#suppressNextCount = false;
      // Record the suppressed count as last-known, or a later genuine search that lands on
      // the pre-suppression count would be treated as a repeat and never announced.
      this.#lastAnnouncedCount = count;
      return;
    }
    if (count === this.#lastAnnouncedCount) {
      return;
    }
    this.#lastAnnouncedCount = count;
    this.a11y.announce(i18n("d_select.results_count", { count }), "polite");
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
      this.#menu?.show();
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

  /**
   * In simple/static mode, moves focus into the listbox on open (searchable mode
   * focuses the filter input instead) so keyboard navigation starts in the options.
   *
   * @param element - The listbox element.
   */
  @action
  focusListboxIfSimple(element: HTMLElement): void {
    if (!this.isStatic) {
      return;
    }
    const target =
      element.querySelector<HTMLElement>('[role="option"][tabindex="0"]') ??
      element.querySelector<HTMLElement>('[role="option"]');
    target?.focus({ preventScroll: true });
  }

  <template>
    <DMenu
      @identifier={{@identifier}}
      @modalForMobile={{true}}
      @matchTriggerWidth={{true}}
      @contentClass="d-combobox__content"
      @trapTab={{false}}
      {{! Typeahead: keep DMenu's default click-to-open (the whole trigger root opens the
        overlay) but disable close-on-click so clicking the already-open trigger/input does
        not toggle it shut. Reset the query on every close; focus the input on open. }}
      @untriggers={{if this.isTypeahead this.emptyTriggers}}
      @onClose={{if this.isTypeahead this.handleMenuClose}}
      @onShow={{if this.isTypeahead this.focusTriggerInput}}
      @onRegisterApi={{this.registerMenu}}
      @triggerClass={{this.triggerClass}}
      {{! Typeahead needs a non-button host because its interactive descendants cannot be
        nested in a button; button and static variants use the DButton trigger. }}
      @triggerComponent={{if (or @multiple this.isTypeahead) (dElement "div")}}
      class="d-combobox"
      ...attributes
    >
      <:trigger as |menuArgs|>
        {{! Resolve the raw @value (stable identity) rather than engine.value, so this
          async context does not churn each render; a content-only skeleton shows while
          it resolves, so a bare id never flashes. }}
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
                @listboxId={{this.listboxId}}
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
          {{dIcon "angle-down" class="d-combobox__caret"}}
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
              @listboxId={{this.listboxId}}
              @expanded={{menuArgs.expanded}}
              @label={{this.ariaLabelText}}
              @placeholder={{or @placeholder (i18n "d_select.placeholder")}}
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
            />
          {{/if}}
          {{dIcon "angle-down" class="d-combobox__caret"}}
        {{else}}
          <DAsyncContent @asyncData={{this.resolveSingle}} @context={{@value}}>
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
          {{dIcon "angle-down" class="d-combobox__caret"}}
        {{/if}}
      </:trigger>

      <:content as |menuArgs|>
        <div class="d-combobox__panel">
          {{#if this.isPanelSearchable}}
            <DFilterInput
              class="d-combobox__filter"
              role="combobox"
              aria-expanded="true"
              aria-controls={{this.listboxId}}
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
              @listboxId={{this.listboxId}}
              @expanded={{menuArgs.expanded}}
              @label={{this.ariaLabelText}}
              @placeholder={{this.searchPlaceholderText}}
              @onOpen={{menuArgs.show}}
              @onRequestClose={{menuArgs.close}}
              @editing={{this.queryActive}}
              @onEdit={{this.beginQuery}}
              @registerInput={{this.captureFilter}}
              {{on "keydown" this.handleInputKeydown}}
            />
          {{/if}}

          <DAsyncContent
            @asyncData={{this.engine.loadItems}}
            @context={{this.engine.loadContext}}
            @debounce={{this.engine.isAsync}}
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

            <:content as |raw|>
              {{#let (this.engine.buildItems raw) as |items|}}
                <ul
                  class="d-combobox__listbox"
                  role="listbox"
                  id={{this.listboxId}}
                  aria-label={{or @label (i18n "d_select.label")}}
                  aria-multiselectable={{booleanString @multiple}}
                  {{didInsert this.announceCount items.length}}
                  {{didUpdate this.announceCount items.length}}
                  {{didInsert this.focusListboxIfSimple}}
                  {{! active mode (input keeps focus) for typeahead/button; focus mode
                    (roving tabindex) for static. Typeahead auto-highlights the first match
                    and re-seeds when async results land (itemsKey = the built array). }}
                  {{dRovingFocus
                    selectionMode=(if this.usesActiveRoving "active" "focus")
                    controllerElement=(if
                      this.usesActiveRoving this.filterInput
                    )
                    itemSelector="[role=option]"
                    itemsKey=(if this.isTypeahead items this.engine.filter)
                    activeClass="--active"
                    onActivate=this.activateElement
                    autoActivateFirst=this.isTypeahead
                  }}
                >
                  {{#each items key="key" as |descriptor|}}
                    <SelectItem
                      @descriptor={{descriptor}}
                      @engine={{this.engine}}
                      @multiple={{@multiple}}
                      @selectedIcon={{@selectedIcon}}
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
                        {{selectItemLabel descriptor.item this.labelField}}
                      {{/if}}
                    </SelectItem>
                  {{/each}}
                </ul>
              {{/let}}
            </:content>

            <:empty>
              <div class="d-combobox__empty" role="status">
                {{or @noResultsLabel (i18n "d_select.no_results")}}
              </div>
            </:empty>

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
        </div>
      </:content>
    </DMenu>
  </template>
}
