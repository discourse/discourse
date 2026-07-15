import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import { getOwner } from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import type DMenuInstance from "discourse/float-kit/lib/d-menu-instance";
import type Site from "discourse/models/site";
import type A11y from "discourse/services/a11y";
import { or } from "discourse/truth-helpers";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DButton from "discourse/ui-kit/d-button";
import DFilterInput from "discourse/ui-kit/d-filter-input";
import DSkeleton from "discourse/ui-kit/d-skeleton";
import dElement from "discourse/ui-kit/helpers/d-element";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dRovingFocus from "discourse/ui-kit/modifiers/d-roving-focus";
import ComboboxQueryInput from "discourse/ui-kit/select/-internals/combobox-query-input";
import SelectItem from "discourse/ui-kit/select/-internals/select-item";
import SelectEngine, {
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
    allowCreate?: SelectEngineOptions["allowCreate"];
    createItem?: SelectEngineOptions["createItem"];
    specialItems?: SelectEngineOptions["specialItems"];
    onChange?: SelectEngineOptions["onChange"];
    placeholder?: string;
    searchPlaceholder?: string;
    noResultsLabel?: string;
    label?: string;
    skeletonCount?: number;
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
 * A single-select combobox built on the headless {@link SelectEngine}. It composes the
 * sanctioned foundations — `DMenu` (overlay + mobile modal), `DAsyncContent` (loading /
 * empty / error, on either a client or a server source), `dRovingFocus` (WAI-ARIA combobox
 * keyboard), and `DSkeleton` (loading) — and wires screen-reader announcements through the
 * `a11y` service.
 *
 * The trigger style is chosen with `@variant` (default `typeahead`):
 * - `typeahead` — the trigger IS a `role="combobox"` input. The default selection label
 *   renders in that input until editing begins; a custom `:selection` renders as a sibling
 *   presentation hidden while the user types. A bare id resolves through `DAsyncContent`
 *   without flashing the id; on mobile the input moves into the modal.
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
    allowCreate: this.args.allowCreate,
    createItem: this.args.createItem,
    specialItems: this.args.specialItems,
    onChange: this.args.onChange,
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

  #listboxId = `d-combobox-listbox-${guidFor(this)}`;

  // The last count announced, so rapid re-filters that don't change the count don't spam
  // the screen reader (and don't compete with the moving `aria-activedescendant`).
  #lastAnnouncedCount: number | null = null;

  // True only for the synchronous span of `focusTriggerInput`, so the query input can tell
  // an open-driven programmatic focus (which must NOT select the label) from a genuine
  // keyboard focus (Tab-in, which selects the label for replacement).
  #focusingFromOpen = false;

  /** The listbox id, wiring `aria-controls`/`aria-activedescendant`. */
  get listboxId(): string {
    return this.#listboxId;
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

  /**
   * Single-select typeahead: the trigger itself is the `role="combobox"` input. Multi
   * keeps the Phase-0 chips-and-panel structure this cycle (multi typeahead is a later
   * item), so `typeahead` only takes effect for single-select.
   */
  get isTypeahead(): boolean {
    return this.variant === SELECT_VARIANTS.typeahead && !this.args.multiple;
  }

  /** Static/simple mode: a short unsearchable list; the listbox takes focus. */
  get isStatic(): boolean {
    return this.variant === SELECT_VARIANTS.static;
  }

  /**
   * Whether the search input lives IN the panel (the `button` variant, and multi until it
   * gains its own typeahead trigger) rather than in the trigger (`typeahead`) or nowhere
   * (`static`).
   */
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
    return this.engine.getSingleSelectionLabel(this.args.value);
  }

  get labelField(): string {
    return this.args.labelField ?? "name";
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
   * Runs on every menu close (typeahead): resets the query so the next open starts clean and
   * the selection presentation resolves synchronously from cache (no re-fetch flash). Multi
   * (a later item) keeps the popover open on select, so it will reset on select instead.
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
   * before the option's `click` resolves. This matters for action rows (which keep the
   * menu open) and for multi (later). Typeahead only — `static` options must take real
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
   * `DAsyncContent`. Narrows the engine's arity-union return to the single form; a
   * null/unresolvable value returns `undefined`, which `DAsyncContent` routes to its
   * `:empty` block (so it is never yielded to `:selection`).
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
   * Resolves the bound ids to their display items for the multi trigger. Narrows to
   * the array form; an empty value returns `undefined` (→ `:empty`), and an
   * unresolvable id is a hole rendered as an empty chip (Phase-0 behavior).
   */
  @action
  resolveMulti(
    value: unknown,
    opts?: SelectLoadOptions
  ): SelectItemModel[] | Promise<SelectItemModel[]> {
    return this.engine.resolveSelection(value as SelectValue, opts) as
      | SelectItemModel[]
      | Promise<SelectItemModel[]>;
  }

  @action
  onFilterInput(event: Event): void {
    this.engine.setFilter((event.target as HTMLInputElement).value);
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
    if (count === this.#lastAnnouncedCount) {
      return;
    }
    this.#lastAnnouncedCount = count;
    this.a11y.announce(i18n("d_select.results_count", { count }), "polite");
  }

  /**
   * Removes a chip's item from the (multi) selection. Stops propagation so the click
   * doesn't also open the menu — the chip lives inside the trigger.
   */
  @action
  removeItem(item: SelectItemModel, event?: MouseEvent): void {
    event?.stopPropagation();
    this.engine.deselect(item);
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
      @triggerClass={{if
        this.isTypeahead
        "d-combobox__trigger --typeahead"
        "d-combobox__trigger"
      }}
      {{! Typeahead (an input) and multi (chip buttons) need a non-button host — a button
        can't nest interactive descendants; single button/static use the DButton trigger. }}
      @triggerComponent={{if (or @multiple this.isTypeahead) (dElement "div")}}
      class="d-combobox"
      ...attributes
    >
      <:trigger as |menuArgs|>
        {{! Resolve the raw @value (stable identity) rather than engine.value, so this
          async context does not churn each render; a content-only skeleton shows while
          it resolves, so a bare id never flashes. }}
        {{#if this.isTypeahead}}
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
                        {{selectItemLabel selected this.labelField}}
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
        {{else if @multiple}}
          <span class="d-combobox__chips">
            <DAsyncContent @asyncData={{this.resolveMulti}} @context={{@value}}>
              <:loading><DSkeleton @variant="text" @width="8ch" /></:loading>
              <:content as |items|>
                {{#each items key="@identity" as |item|}}
                  <button
                    type="button"
                    class="d-combobox__chip"
                    title={{i18n "d_select.remove"}}
                    {{on "click" (fn this.removeItem item)}}
                  >
                    <span class="d-combobox__chip-label">
                      {{#if (has-block "selection")}}
                        {{yield item to="selection"}}
                      {{else}}
                        {{selectItemLabel item this.labelField}}
                      {{/if}}
                    </span>
                    {{dIcon "xmark" class="d-combobox__chip-remove"}}
                  </button>
                {{/each}}
              </:content>
              <:empty>
                <span class="d-combobox__placeholder">
                  {{or @placeholder (i18n "d_select.placeholder")}}
                </span>
              </:empty>
            </DAsyncContent>
            <DButton
              class="d-combobox__expand btn-transparent"
              @icon="angle-down"
              @action={{menuArgs.show}}
              @title="d_select.expand"
            />
          </span>
        {{else}}
          <DAsyncContent @asyncData={{this.resolveSingle}} @context={{@value}}>
            <:loading><DSkeleton @variant="text" @width="8ch" /></:loading>
            <:content as |selected|>
              <span class="d-combobox__value">
                {{#if (has-block "selection")}}
                  {{yield selected to="selection"}}
                {{else}}
                  {{selectItemLabel selected this.labelField}}
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
