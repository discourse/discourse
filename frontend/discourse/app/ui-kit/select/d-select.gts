import Component from "@glimmer/component";
import { assert } from "@ember/debug";
import { associateDestroyableChild } from "@ember/destroyable";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import Owner, { getOwner } from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import type { MenuOptions } from "discourse/float-kit/lib/constants";
import type Menu from "discourse/float-kit/services/menu";
import booleanString from "discourse/helpers/boolean-string";
import type A11y from "discourse/services/a11y";
import type { CapabilitiesService } from "discourse/services/capabilities";
import DFilterInput from "discourse/ui-kit/d-filter-input";
import dElement from "discourse/ui-kit/helpers/d-element";
import InteractionCoordinator from "discourse/ui-kit/select/-internals/coordinators/interaction-coordinator";
import LoadFeedbackTracker from "discourse/ui-kit/select/-internals/coordinators/load-feedback";
import SelectAnnouncer from "discourse/ui-kit/select/-internals/coordinators/select-announcer";
import VariantPresenter, {
  type SelectVariant,
} from "discourse/ui-kit/select/-internals/coordinators/variant-presenter";
import WindowedListCoordinator from "discourse/ui-kit/select/-internals/coordinators/windowed-list-coordinator";
import keepAboveKeyboard from "discourse/ui-kit/select/-internals/modifiers/keep-above-keyboard";
import ComboboxQueryInput from "discourse/ui-kit/select/-internals/parts/combobox-query-input";
import MultiChips from "discourse/ui-kit/select/-internals/parts/multi-chips";
import SelectListbox, {
  type SelectListContent,
} from "discourse/ui-kit/select/-internals/parts/select-listbox";
import SingleTriggerDisplay from "discourse/ui-kit/select/-internals/parts/single-trigger-display";
import TriggerFrame from "discourse/ui-kit/select/-internals/parts/trigger-frame";
import SelectEngine, {
  type SelectDescriptor,
  type SelectEngineOptions,
  type SelectItem as SelectItemModel,
  type SelectLoadOptions,
  type SelectValue,
} from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

export type { SelectVariant } from "discourse/ui-kit/select/-internals/coordinators/variant-presenter";

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
    valueItems?: SelectItemModel | SelectItemModel[];
    resolveValue?: SelectEngineOptions["resolveValue"];
    resolveValues?: SelectEngineOptions["resolveValues"];
    allowCreate?: SelectEngineOptions["allowCreate"];
    createItem?: SelectEngineOptions["createItem"];
    createUnresolvedItem?: SelectEngineOptions["createUnresolvedItem"];
    specialItems?: SelectEngineOptions["specialItems"];
    /**
     * Groups the options: a field name or `(item) => key`. A boundary renders as a labeled
     * header where `@groupLabel` yields text and as an unlabeled splitter otherwise. Client
     * sources only. Recomputed after filtering, so an empty group draws nothing.
     */
    groupBy?: SelectEngineOptions["groupBy"];
    /**
     * Maps a group key to its header text. Nullish for a key renders that boundary as an
     * unlabeled splitter; omitted entirely, every boundary is a splitter.
     */
    groupLabel?: SelectEngineOptions["groupLabel"];
    onChange?: SelectEngineOptions["onChange"];
    placeholder?: string;
    searchPlaceholder?: string;
    noResultsLabel?: string;
    label?: string;
    /**
     * Identity and description for the element that actually carries `role="combobox"`, which
     * differs by variant: the trigger root on `static`, the query input otherwise. Passing them
     * as `...attributes` instead would land them on the wrapper, where a `<label for>` resolves
     * to nothing and a description is never announced.
     *
     * `@describedBy` is merged with the component's own description ids rather than replacing
     * them.
     */
    id?: string;
    describedBy?: string;
    /** Marks the control invalid (`aria-invalid`), for a form that owns the validation. */
    invalid?: boolean;
    skeletonCount?: number;
    /**
     * Icon marking the selected row(s) in the list. Multi-select always shows it (defaulting to a
     * check); single-select renders it only when this arg is set, so an ordinary single-select has
     * no icon column.
     */
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
     * Renders a label-less, icon-only trigger: the value / placeholder text is suppressed, leaving
     * the leading `@icon` and the caret. Only takes effect on the `button` and `static`
     * single-select variants — a `typeahead` trigger is an editable input and a multi-select shows
     * chips, so neither can be icon-only. Requires `@label`: with no visible text, `@label` is the
     * trigger's accessible name (enforced by a debug assertion). Drive `@icon` from `@value` for a
     * selection-reactive glyph.
     */
    iconOnly?: boolean;
    /**
     * The caret icon. A bare string is used in both states; a `{ open, closed }` hash swaps on
     * open (keyed off the overlay's expanded state). Defaults to `angle-up` / `angle-down`.
     */
    caretIcon?: string | { open?: string; closed?: string };
    /** Whether the trigger shows its caret. Defaults to `true`; set `false` for an icon-only trigger. */
    showCaret?: boolean;
    /**
     * Show a clear control that empties the whole selection (all variants, whenever there is a
     * value). Purely a pointer affordance (`tabindex="-1"`).
     *
     * It does NOT gate clearing by keyboard, which is always available from an empty query:
     * Backspace removes the last chip in multi-select (repeat to empty it), and Backspace or
     * Delete clears a single selection. That matches the family this replaces, which clears on
     * Backspace-with-an-empty-filter with no opt-in — so a picker is never a place a reader can
     * reach a value but not leave.
     */
    clearable?: boolean;
    /** Fully disables the control: not focusable, cannot open, cannot mutate. */
    disabled?: boolean;
    /** Locks the value: focusable and readable, but cannot open, edit, or mutate. */
    readonly?: boolean;
    /** Whether a source error offers a retry action. Defaults to `true`. */
    retryable?: boolean;
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
    /**
     * Hard cap on a multi-select's selection count. At the cap every unselected ordinary option
     * is disabled (non-interactive and skipped by keyboard navigation) and the limit message
     * appears. The cap never *newly* disables a selected row, so deselecting one is the way back
     * under it (a row the consumer marked `disabled` stays disabled either way, though its chip
     * remains removable); action rows stay enabled too, since they never become a value. Ignored
     * on a single-select, and unset below `1`.
     *
     * A value that arrives already over the cap is never trimmed: every held id still renders
     * and can still be removed, only additions are refused. The cap is checked against the value
     * read at activation time, so it assumes `@onChange` is applied synchronously and by
     * replacement; a consumer that applies it asynchronously or merges additively can still
     * exceed it. For a single choice use `@multiple={{false}}` rather than `@maximum={{1}}`.
     */
    maximum?: number;
    /**
     * Advisory minimum for a multi-select: it shows a "select at least N" message and exposes
     * the state, but never blocks anything — deselecting and clearing always succeed, down to an
     * empty selection. Submit-time enforcement belongs to the consuming form.
     */
    minimum?: number;
    /**
     * Single-select only: adds a first-class "none" row to the top of the list, labeled with this
     * string. Selecting it clears the value to `null`, and the row reads as selected whenever
     * nothing else is. It is a list affordance shown only while browsing (an active filter query
     * hides it, so a non-matching search still reaches the empty state), and after choosing it the
     * trigger shows the placeholder — `null` cannot encode "None" in the trigger. Ignored on
     * multi-select, where the empty state is the placeholder rather than a row.
     */
    noneLabel?: string;
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
    /**
     * Custom markup for the selected item; yields the resolved item. On the button/static
     * triggers it is the persistent selected display. On the typeahead it is the resting (closed)
     * display only: once the menu opens the built-in input shows the editable label text instead,
     * so the block is not a live-while-editing surface.
     */
    selection?: [SelectItemModel];
    /** Consumer override for a group header's content; yields the header item (with its `label`). */
    groupHeader?: [SelectItemModel];
    /** Consumer override for the no-results state, replacing the default "No results found". */
    empty?: [];
    /**
     * Content pinned below the option list (labels, links, action buttons). Yields the live
     * dropdown state so the content can react (e.g. a "plus N more" from `total - loadedCount`).
     */
    footer?: [SelectFooterState];
    /**
     * Consumer override for the source-error state, replacing the default muted message + retry.
     * Yields the rejection reason and a `retry` action.
     */
    error?: [Error, () => void];
  };
}

/** The live state yielded to the `:footer` block so its content can react to the dropdown. */
interface SelectFooterState {
  /** The current filter query. */
  filter: string;
  /** The current value (id or id array). */
  value: SelectValue;
  /** Whether anything is selected. */
  hasValue: boolean;
  /** The whole result-set size, or `undefined` when a paginating source hasn't reported one. */
  total: number | undefined;
  /** How many options are currently loaded into the list (`total - loadedCount` = "more"). */
  loadedCount: number;
  /** The multi-select selection cap, or `null` when uncapped. */
  maximum: number | null;
  /** The advisory multi-select minimum (`0` = none). */
  minimum: number;
  /** Whether the selection has reached {@link maximum}. */
  atMaximum: boolean;
  /** Whether the selection is still short of the advisory {@link minimum}. */
  belowMinimum: boolean;
  /** How many more items may still be added, or `undefined` when uncapped. */
  remaining: number | undefined;
  /** Dismisses the overlay (for a footer action such as "View all"). */
  close: () => void;
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
  @service declare capabilities: CapabilitiesService;
  @service declare menu: Menu;

  announcer: SelectAnnouncer;
  interaction: InteractionCoordinator;

  // Constructed once from the (stable) args; never exposed to consumers — internal
  // parts receive it but touch only its public API.
  engine = new SelectEngine({
    // Read lazily so the engine reflects the parent's (reactive) @value — controlled.
    getValue: () => this.args.value,
    // Live readers for the reactive inputs, so a runtime change to any of these args
    // propagates into the engine (which reads them on every access). Static-by-contract
    // args below are passed by value.
    getMultiple: () => this.args.multiple,
    identifiers: this.args.identifiers ?? this.args.identifier,
    getMinChars: () => this.args.minChars,
    getMaximum: () => this.args.maximum,
    getMinimum: () => this.args.minimum,
    getNoneLabel: () => this.args.noneLabel,
    items: () =>
      typeof this.args.items === "function"
        ? this.args.items()
        : this.args.items,
    load: this.args.load,
    filterBy: this.args.filterBy,
    valueField: this.args.valueField,
    labelField: this.args.labelField,
    // Passed only when the consumer actually declared the arg. An arg that is present but
    // still empty is the late-arrival pattern mid-flight; withholding the reader entirely is
    // what lets the engine tell that apart from "no identity mechanism was ever supplied".
    getValueItems:
      "valueItems" in this.args ? () => this.args.valueItems : undefined,
    resolveValue: this.args.resolveValue,
    resolveValues: this.args.resolveValues,
    getAllowCreate: () => this.args.allowCreate,
    createItem: this.args.createItem,
    createUnresolvedItem: this.args.createUnresolvedItem,
    specialItems: this.args.specialItems,
    groupBy: this.args.groupBy,
    groupLabel: this.args.groupLabel,
    onChange: this.handleChange,
    // Gated on the overlay actually being open: `DMenuInstance.close` focuses the trigger by
    // default, so closing an already-closed menu would steal focus from wherever the user has
    // moved on to. Reachable from the compat bridge, which exposes both `close()` and a
    // `select()` that consumers call asynchronously long after dismissing the overlay.
    requestClose: () => {
      if (this.interaction.isExpanded) {
        this.interaction.closeMenu();
      }
    },
    // Handles for the `modifySelectKit` compat bridge. The element must be the trigger
    // (which stays in the host DOM) — not the panel, which the overlay portals out — so
    // legacy callbacks that walk up from it (e.g. `.closest("#reply-control")`) resolve.
    legacy: {
      owner: getOwner(this),
      // The bridge anchor must be a real host-DOM node (legacy callbacks walk up from it,
      // e.g. `.closest("#reply-control")`). `triggerElement` is the instance's trigger
      // narrowed to `HTMLElement` (null for a virtual trigger — never our case).
      getElement: () => this.interaction.triggerElement,
      isDestroyed: () => this.isDestroying || this.isDestroyed,
    },
  });

  presenter = new VariantPresenter({
    getArgs: () => this.args,
    engine: this.engine,
    shouldRenderInModal: (modalForMobile) =>
      this.menu.shouldRenderInModal(modalForMobile),
    isExpanded: () => this.interaction.isExpanded,
    activeListboxId: () => this.activeListboxId,
  });

  feedback = new LoadFeedbackTracker({
    engine: this.engine,
    getDebounce: () => this.presenter.debounce,
    getSkeletonCountArg: () => this.args.skeletonCount,
  });

  listbox = new WindowedListCoordinator({
    engine: this.engine,
    feedback: this.feedback,
    getListboxId: () => this.listboxId,
    isStaticModal: () =>
      this.presenter.isStatic && this.presenter.overlayIsModal,
  });

  #listboxId = `d-combobox-listbox-${guidFor(this)}`;

  constructor(owner: Owner, args: DSelectSignature["Args"]) {
    super(owner, args);
    this.announcer = new SelectAnnouncer({
      a11y: this.a11y,
      engine: this.engine,
      getActiveOptionKey: () => this.listbox.activeOptionKey,
      reannounceActive: () => this.listbox.reannounceActive(),
      getNoResultsLabel: () => this.args.noResultsLabel,
      getShouldSuppressEntryCount: () =>
        this.presenter.shouldActivateSelected ||
        this.presenter.shouldAutoActivateFirst,
    });
    this.interaction = new InteractionCoordinator({
      engine: this.engine,
      presenter: this.presenter,
      announcer: this.announcer,
      capabilities: this.capabilities,
      onShow: () => this.args.onShow?.(),
      onClose: () => this.args.onClose?.(),
      isMultiple: () => this.args.multiple,
    });
    associateDestroyableChild(this, this.feedback);
    associateDestroyableChild(this, this.listbox);
    associateDestroyableChild(this, this.announcer);
    associateDestroyableChild(this, this.interaction);
  }

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

  /**
   * Stable id for the resting selection markup, so the combobox can point at it.
   *
   * A `:selection` block moves the selected label out of the input and into a sibling span,
   * leaving the input's value empty until it takes focus. Without this association the control
   * would read as an empty combobox while the eye sees a selection.
   */
  get selectionId() {
    return `d-combobox-selection-${guidFor(this)}`;
  }

  /**
   * Catches a bare `disabled` attribute, which does nothing here and fails silently: the trigger
   * root is a `div`, so the attribute is inert, and the control renders fully interactive while
   * looking correctly configured. Native form controls take the attribute, so reaching for it is
   * the obvious mistake.
   *
   * The attribute is not read and honoured instead: `...attributes` are not visible to the
   * component, so doing that means inspecting the DOM after render and mirroring it into tracked
   * state — a second source of truth for a state the component already owns.
   */
  @action
  assertDisabledIsAnArg(element: HTMLElement): void {
    assert(
      "DSelect: `disabled` is an argument, not an attribute — write `@disabled` instead. " +
        "The trigger is a `div`, so a bare `disabled` attribute is inert and the control stays " +
        "interactive.",
      !element.hasAttribute("disabled") || this.args.disabled != null
    );
  }

  /**
   * Composes an `aria-describedby` token list from the component's own description ids and the
   * consumer's `@describedBy`, dropping the empty ones.
   *
   * A merge rather than a fallback because both sides are real: the component describes its own
   * state (the chip-navigation hint, the resting selection) while a form describes the field
   * (its validation message). Letting either win silently discards the other, and the loss is
   * inaudible to anyone not using a screen reader.
   */
  describedBy(...ids: Array<string | undefined | false>): string | undefined {
    const tokens = ids.filter(Boolean);
    return tokens.length ? tokens.join(" ") : undefined;
  }

  @action
  loadListContent(
    context: unknown,
    opts?: SelectLoadOptions
  ): SelectListContent | Promise<SelectListContent> {
    const rawItems = this.engine.loadItems(context, opts);
    // Stamped at resolve time, not call time: an aborted-then-superseded load never reaches
    // here, so the filter read on resolution is the one these rows were fetched for.
    return rawItems instanceof Promise
      ? rawItems.then((items) => ({
          rawItems: items,
          filter: this.engine.filter,
        }))
      : { rawItems, filter: this.engine.filter };
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

  @action
  handleChange(
    nextValue: SelectValue,
    payload: SelectItemModel | SelectItemModel[] | null
  ): void {
    // This must be read before forwarding because the parent applies nextValue synchronously.
    const oldValues = this.args.value;
    this.announcer.valueChanged(oldValues, nextValue, {
      onAddedWithQuery: () => {
        this.engine.setFilter("");
        this.interaction.queryActive = false;
      },
    });
    this.args.onChange?.(nextValue, payload);
  }

  @action
  onFilterInput(event: Event): void {
    this.engine.setFilter((event.target as HTMLInputElement).value);
  }

  <template>
    <DMenu
      @identifier={{@identifier}}
      @modalForMobile={{true}}
      @contentRole={{this.presenter.panelContentRole}}
      @matchTriggerWidth={{true}}
      {{! The menu's default 400px cap is applied inline, exactly like the matched width, so it
        wins over it: a field wider than the cap gets a visibly narrower dropdown. A combobox
        overlay belongs to its field, so the field's width is the only bound. The CSS floor on
        the combobox content class still stops a compact icon-only trigger from being matched
        down to nothing. }}
      @maxWidth="none"
      @placement={{@placement}}
      @offset={{@offset}}
      {{! The d-combobox__content class floors the overlay min-width in CSS: matchTriggerWidth pins
        it to the trigger, which is unusably narrow for a compact icon-only trigger, and the
        min-width floor overrides that (it also gives the windowed option list a real width). }}
      @contentClass="d-combobox__content"
      @trapTab={{false}}
      {{! Typeahead: keep DMenu's default click-to-open (the whole trigger root opens the
        overlay) but disable close-on-click so clicking the already-open trigger/input does
        not toggle it shut, and focus the input on open. Resetting the query is not scoped
        here — every variant clears on close, inside the interaction coordinator's close
        handler. }}
      @untriggers={{if
        this.presenter.isTypeahead
        this.interaction.emptyTriggers
      }}
      {{! DMenu vetoes its own trigger open while locked, reactively. Keyboard/edit open + all
        mutate paths are gated separately in this component (they are not DMenu listeners). }}
      @disabled={{this.presenter.isLocked}}
      @onClose={{this.interaction.handleClose}}
      @onShow={{this.interaction.handleShow}}
      {{! The overlay is sized by its positioning, which lands after the windowed list has
        already measured itself against an unsized overlay. }}
      @onPositioned={{this.listbox.remeasureListbox}}
      @onRegisterApi={{this.interaction.registerMenu}}
      @triggerClass={{this.presenter.triggerClass}}
      {{! Control variants put ARIA and keyboard behavior on the root; input variants put
        them on their inner input. }}
      @triggerComponent={{dElement "div"}}
      data-unresolved={{if this.presenter.hasUnresolvedSelection "true"}}
      {{! Identity and description follow the combobox role, which lives here only on the
        variants without a query input; the typeahead carries them on its input instead. Applied
        unconditionally would give a typeahead two elements with the same id. }}
      id={{unless this.presenter.isTypeahead @id}}
      aria-invalid={{unless
        this.presenter.isTypeahead
        (booleanString @invalid)
      }}
      aria-describedby={{unless this.presenter.isTypeahead @describedBy}}
      role={{this.presenter.triggerRootRole}}
      tabindex={{this.presenter.triggerRootTabIndex}}
      aria-label={{this.presenter.triggerRootLabel}}
      aria-haspopup={{this.presenter.triggerRootHasPopup}}
      aria-controls={{this.presenter.triggerRootControls}}
      aria-disabled={{this.presenter.triggerRootDisabled}}
      aria-readonly={{this.presenter.triggerRootReadonly}}
      {{on "keydown" this.interaction.handleTriggerRootKeydown}}
      {{! eslint-disable-next-line ember/template-no-pointer-down-event-binding }}
      {{on "mousedown" this.interaction.preventTriggerBlur}}
      {{didInsert this.interaction.registerStaticController}}
      {{didInsert this.assertDisabledIsAnArg}}
      class="d-combobox"
      ...attributes
    >
      <:trigger as |menuArgs|>
        {{! Resolve the raw @value (stable identity) rather than engine.value, so this
          async context does not churn each render; a content-only skeleton shows while
          it resolves, so a bare id never flashes. }}
        <TriggerFrame
          @icon={{@icon}}
          @caret={{this.presenter.caretIcon}}
          @showCaret={{this.presenter.showCaret}}
          @showClear={{this.presenter.showClear}}
          @clearLabel={{this.presenter.clearLabel}}
          @onClear={{this.interaction.handleClear}}
          @onLabelActivate={{this.interaction.focusFromLabel}}
        >
          {{#if @multiple}}
            <MultiChips
              @value={{@value}}
              @engine={{this.engine}}
              @presenter={{this.presenter}}
              @listboxId={{this.activeListboxId}}
              @expanded={{menuArgs.expanded}}
              @editing={{this.interaction.queryActive}}
              @id={{@id}}
              @invalid={{@invalid}}
              @describedBy={{@describedBy}}
              @hasSelectionBlock={{has-block "selection"}}
              @resolveSelection={{this.resolveMulti}}
              @composeDescribedBy={{this.describedBy}}
              @showMenu={{menuArgs.show}}
              @closeMenu={{menuArgs.close}}
              @focusInput={{this.interaction.focusInput}}
              @focusChip={{this.interaction.focusChip}}
              @onRegisterChipRoving={{this.interaction.registerChipRoving}}
              @shouldSelectOnFocus={{this.interaction.shouldSelectOnFocus}}
              @onEdit={{this.interaction.beginQuery}}
              @registerInput={{this.interaction.registerTriggerInput}}
              @onBlur={{this.interaction.handleTriggerBlur}}
              @onInputKeydown={{this.interaction.handleInputKeydown}}
              @shouldCorrectKeyboardOcclusion={{this.interaction.shouldCorrectKeyboardOcclusion}}
            >
              <:selection as |item|>{{yield item to="selection"}}</:selection>
            </MultiChips>
          {{else}}
            <SingleTriggerDisplay
              @value={{@value}}
              @engine={{this.engine}}
              @presenter={{this.presenter}}
              @listboxId={{this.activeListboxId}}
              @expanded={{menuArgs.expanded}}
              @placeholder={{@placeholder}}
              @editing={{this.interaction.queryActive}}
              @triggerFocused={{this.interaction.triggerFocused}}
              @id={{@id}}
              @invalid={{@invalid}}
              @describedBy={{@describedBy}}
              @selectionId={{this.selectionId}}
              @hasSelectionBlock={{has-block "selection"}}
              @resolveSelection={{this.resolveSingle}}
              @composeDescribedBy={{this.describedBy}}
              @showMenu={{menuArgs.show}}
              @closeMenu={{menuArgs.close}}
              @shouldSelectOnFocus={{this.interaction.shouldSelectOnFocus}}
              @onBlur={{this.interaction.handleTriggerBlur}}
              @onEdit={{this.interaction.beginQuery}}
              @registerInput={{this.interaction.registerTriggerInput}}
              @onInputKeydown={{this.interaction.handleInputKeydown}}
              @onFocus={{this.interaction.handleTriggerFocus}}
              @shouldCorrectKeyboardOcclusion={{this.interaction.shouldCorrectKeyboardOcclusion}}
            >
              <:selection as |item|>{{yield item to="selection"}}</:selection>
            </SingleTriggerDisplay>
          {{/if}}
        </TriggerFrame>
      </:trigger>

      <:content as |menuArgs|>
        <div
          class="d-combobox__panel"
          {{didInsert
            this.feedback.trackLoadFeedback
            this.engine.serverPending
          }}
          {{didUpdate
            this.feedback.trackLoadFeedback
            this.engine.serverPending
          }}
          {{willDestroy this.feedback.releaseLoadFeedback}}
        >
          {{#if this.presenter.isPanelSearchable}}
            <DFilterInput
              class="d-combobox__filter"
              role="combobox"
              aria-expanded="true"
              aria-controls={{this.activeListboxId}}
              aria-autocomplete="list"
              autocomplete="off"
              {{! The disclosure trigger hands focus straight here on open, so this is the first
                thing a reader meets. A placeholder is a last-resort name source that screen
                readers treat inconsistently — name it after the field it narrows. }}
              aria-label={{this.presenter.ariaLabelText}}
              placeholder={{this.presenter.searchPlaceholderText}}
              @value={{this.engine.filter}}
              @filterAction={{this.onFilterInput}}
              @icons={{hash left="magnifying-glass"}}
              {{didInsert this.interaction.captureFilter}}
            />
          {{else if this.presenter.isMobileTypeahead}}
            {{! Mobile: the query input lives inside the modal (an external host input can't
              function behind an aria-modal). No aria-owns (input + listbox share the modal
              subtree); no blur-close (the modal owns dismissal). }}
            <ComboboxQueryInput
              class="d-combobox__filter"
              @engine={{this.engine}}
              @listboxId={{this.activeListboxId}}
              @expanded={{menuArgs.expanded}}
              @label={{this.presenter.ariaLabelText}}
              @placeholder={{this.presenter.searchPlaceholderText}}
              @onOpen={{menuArgs.show}}
              @onRequestClose={{menuArgs.close}}
              @editing={{this.interaction.queryActive}}
              @onEdit={{this.interaction.beginQuery}}
              @registerInput={{this.interaction.captureFilter}}
              @disabled={{this.presenter.isDisabled}}
              @readonly={{this.presenter.isReadonly}}
              {{keepAboveKeyboard
                this.interaction.shouldCorrectKeyboardOcclusion
              }}
              {{on "keydown" this.interaction.handleInputKeydown}}
            />
          {{/if}}

          {{#if this.presenter.limitMessage}}
            {{#unless this.engine.belowMinChars}}
              {{! A pinned top zone (sibling of the list, above it), so the cap/floor hint never
                stacks with the footer or an error body. Suppressed while below the query minimum:
                with no list rendered the hint has nothing to annotate. Announced through the a11y
                service (a mounted live region speaks unreliably); the node stays role=status. }}
              <div
                class="d-combobox__limit"
                role="status"
                {{didInsert
                  this.announcer.announceLimitOnEntry
                  this.presenter.limitMessage
                }}
                {{didUpdate
                  this.announcer.announceLimit
                  this.presenter.limitMessage
                }}
              >
                {{this.presenter.limitMessage}}
              </div>
            {{/unless}}
          {{/if}}

          {{#if this.engine.belowMinChars}}
            {{! Below the minimum query length: no source call (no request, no skeleton flash),
              and the truthy-empty-array routing / stray create-row are sidestepped by not
              rendering the list at all. The hint is announced through the a11y service (see announceMinChars);
              the visible node stays a status region for sighted users. }}
            <div
              class="d-combobox__min-chars"
              role="status"
              {{didInsert
                this.announcer.announceMinCharsOnEntry
                this.engine.remainingMinChars
              }}
              {{didUpdate
                this.announcer.announceMinChars
                this.engine.remainingMinChars
              }}
            >
              {{i18n "d_select.min_chars" count=this.engine.remainingMinChars}}
            </div>
          {{else}}
            <SelectListbox
              @engine={{this.engine}}
              @presenter={{this.presenter}}
              @feedback={{this.feedback}}
              @listbox={{this.listbox}}
              @announcer={{this.announcer}}
              @loadListContent={{this.loadListContent}}
              @filterInput={{this.interaction.filterInput}}
              @listboxId={{this.listboxId}}
              @selectedIcon={{@selectedIcon}}
              @multiple={{@multiple}}
              @label={{@label}}
              @noResultsLabel={{@noResultsLabel}}
              @hasItemBlock={{has-block "item"}}
              @hasGroupHeaderBlock={{has-block "groupHeader"}}
              @hasEmptyBlock={{has-block "empty"}}
              @hasErrorBlock={{has-block "error"}}
              @onOptionMousedown={{this.interaction.preventPointerBlur}}
            >
              <:item as |item|>{{yield item to="item"}}</:item>
              <:groupHeader as |item|>
                {{yield item to="groupHeader"}}
              </:groupHeader>
              <:empty>{{yield to="empty"}}</:empty>
              <:error as |error retry|>{{yield error retry to="error"}}</:error>
            </SelectListbox>
          {{/if}}
          {{#if (has-block "footer")}}
            {{! A labeled region pinned below the list (a sibling of the listbox, never inside it).
              Keyboard-reachable via float-kit's Tab-forward; a desktop focus-out closes the menu. }}
            <div
              class="d-combobox__footer"
              role="group"
              aria-label={{i18n "d_select.footer_label"}}
              {{on "focusout" this.interaction.handleFooterFocusOut}}
            >
              {{yield
                (hash
                  filter=this.engine.filter
                  value=this.engine.value
                  hasValue=this.engine.hasValue
                  total=this.engine.total
                  loadedCount=this.engine.loadedCount
                  maximum=this.engine.maximum
                  minimum=this.engine.minimum
                  atMaximum=this.engine.atMaximum
                  belowMinimum=this.engine.belowMinimum
                  remaining=this.engine.remaining
                  close=menuArgs.close
                )
                to="footer"
              }}
            </div>
          {{/if}}
        </div>
      </:content>
    </DMenu>
  </template>
}
