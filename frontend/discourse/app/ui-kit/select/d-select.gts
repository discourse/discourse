import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
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
import { cancel, schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { TrackedAsyncData } from "ember-async-data";
import { modifier } from "ember-modifier";
import DMenu from "discourse/float-kit/components/d-menu";
import type { MenuOptions } from "discourse/float-kit/lib/constants";
import type Menu from "discourse/float-kit/services/menu";
import type A11y from "discourse/services/a11y";
import type { CapabilitiesService } from "discourse/services/capabilities";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DFilterInput from "discourse/ui-kit/d-filter-input";
import dElement from "discourse/ui-kit/helpers/d-element";
import InteractionCoordinator from "discourse/ui-kit/select/-internals/coordinators/interaction-coordinator";
import SelectHost, {
  type SelectPasteContext,
} from "discourse/ui-kit/select/-internals/coordinators/select-host";
import VariantPresenter, {
  type SelectVariant,
} from "discourse/ui-kit/select/-internals/coordinators/variant-presenter";
import type { SelectResolvedOptions } from "discourse/ui-kit/select/-internals/engine/customizations";
import keepAboveKeyboard from "discourse/ui-kit/select/-internals/modifiers/keep-above-keyboard";
import ComboboxQueryInput from "discourse/ui-kit/select/-internals/parts/combobox-query-input";
import MultiChips from "discourse/ui-kit/select/-internals/parts/multi-chips";
import SelectOptions from "discourse/ui-kit/select/-internals/parts/select-options";
import SelectionStrip from "discourse/ui-kit/select/-internals/parts/selection-strip";
import SingleTriggerDisplay from "discourse/ui-kit/select/-internals/parts/single-trigger-display";
import TriggerFrame from "discourse/ui-kit/select/-internals/parts/trigger-frame";
import WindowedOptionList from "discourse/ui-kit/select/-internals/parts/windowed-option-list";
import type {
  SelectDescriptor,
  SelectEngineOptions,
  SelectItem as SelectItemModel,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

export type { SelectVariant } from "discourse/ui-kit/select/-internals/coordinators/variant-presenter";

export type { SelectPasteContext } from "discourse/ui-kit/select/-internals/coordinators/select-host";

interface DSelectSignature {
  Args: {
    value?: SelectValue;
    multiple?: boolean;
    /**
     * Maximum chips displayed in a multi trigger. Zero shows only the held count;
     * positive values show the first N chips and a +K badge. Removal moves to the panel.
     */
    maxVisibleChips?: number;
    /**
     * Parses pasted text into a batch. Nullish results preserve native paste; arrays
     * add eligible items and clear the original query. Async results lose authority
     * to newer selection intent; newer typing and sessions keep their query.
     */
    parsePaste?: (
      text: string,
      context: SelectPasteContext
    ) =>
      | readonly SelectItemModel[]
      | null
      | undefined
      | Promise<readonly SelectItemModel[] | null | undefined>;
    /** The select's recipe or family, fixed at construction. */
    kind?: string;
    /** Declares recipe option keys and their live base values. Requires `@kind`; core keys are reserved. */
    kindOptions?: Record<string, unknown>;
    /** The call-site name used for customization and menu identity. */
    identifier?: string;
    /** A recipe's own data, passed to customizations as `context.kindContext`. */
    kindContext?: object;
    /**
     * The call site's data, passed to customizations as `context.instanceContext`. A recipe forwards the
     * one it was given.
     */
    instanceContext?: object;
    items?: SelectEngineOptions["items"];
    load?: SelectEngineOptions["load"];
    /** Loader inputs, compared by own keys and value identity to reload the list. */
    loadContext?: SelectEngineOptions["loadContext"];
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
     * Groups the options: a field name or `(item, options) => key`. A boundary renders as a labeled
     * header where `@groupLabel` yields text and as an unlabeled splitter otherwise. Client
     * sources only. Recomputed after filtering, so an empty group draws nothing.
     */
    groupBy?: SelectEngineOptions["groupBy"];
    /**
     * `(key, options) => text` maps a group key to its header text. Nullish renders an
     * unlabeled splitter; omitted entirely, every boundary is a splitter.
     */
    groupLabel?: SelectEngineOptions["groupLabel"];
    /** Receives the next value, resolved items, and metadata including resolved options. */
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
     * Suppresses value/placeholder text on single-select `button` and `static` triggers.
     * Requires a resolved label; ignored with a debug warning otherwise.
     * Drive `@icon` from `@value` for a selection-reactive glyph.
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
     * so a client source never flashes a loading skeleton while an async one is throttled. Only a
     * filter change waits; a reveal or a reload fetches at once.
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
     * is disabled (navigable, with activation blocked) and the limit message
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
    /** Custom markup for an option and its resolved options snapshot. */
    item?: [
      /** The raw option item. */
      item: SelectItemModel,
      /** Resolved core and recipe values. */
      options: SelectResolvedOptions,
    ];
    /**
     * Custom markup for the selected item; yields the resolved item. On the button/static
     * triggers it is the persistent selected display. On the typeahead it is the resting (closed)
     * display only: once the menu opens the built-in input shows the editable label text instead,
     * so the block is not a live-while-editing surface.
     */
    selection?: [
      /** The resolved held item. */
      item: SelectItemModel,
      /** Resolved core and recipe values. */
      options: SelectResolvedOptions,
    ];
    /**
     * Shown in place of a held selection while it resolves: in each chip, or in the single
     * trigger. Without it a plain text bar stands in.
     */
    selectionLoading?: [];
    /**
     * Custom markup for a held value that cannot be resolved (deleted, restricted or never
     * existed); yields the fallback item. Without it the built-in label is used ("Unknown item
     * (id)", or the name `@createUnresolvedItem` gives), even when `:selection` is supplied, so
     * the state is never lost in custom markup by accident.
     */
    unresolved?: [
      /** The fallback for an unresolved held id. */
      item: SelectItemModel,
      /** Resolved core and recipe values. */
      options: SelectResolvedOptions,
    ];
    /** Consumer override for a group header's content; yields the header item (with its `label`). */
    groupHeader?: [
      /** The synthetic header item. */
      item: SelectItemModel,
      /** Resolved core and recipe values. */
      options: SelectResolvedOptions,
    ];
    /**
     * One placeholder row, shown while a page of rows loads (the first load, or more rows
     * arriving at the end of the list). Repeated per row, so it should match the shape of `:item`.
     */
    loadingItem?: [];
    /** Consumer override for the no-results state, replacing the default "No results found". */
    empty?: [];
    /**
     * Content pinned below the option list (labels, links, action buttons). Yields the live
     * dropdown state so the content can react (e.g. a "plus N more" from `total - loadedCount`).
     */
    footer?: [
      /** The live dropdown state. */
      state: SelectFooterState,
      /** Resolved core and recipe values. */
      options: SelectResolvedOptions,
    ];
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
 * keyboard, ARIA, positioning, mobile — is handled. Recipes wrap this with a domain source
 * and row markup.
 */
export default class DSelect extends Component<DSelectSignature> {
  @service declare a11y: A11y;
  @service declare capabilities: CapabilitiesService;
  @service declare menu: Menu;

  interaction: InteractionCoordinator;

  host = new SelectHost({
    owner: getOwner(this),
    getA11y: () => this.a11y,
    getArgs: () => this.args,
    getPresenter: () => this.presenter,
    getMultiple: () => this.args.multiple,
    isLive: () => !this.isDestroying && this.interaction.isExpanded,
    session: () => this.interaction.session,
    clearQuery: () => {
      this.engine.setFilter("");
      this.interaction.queryActive = false;
    },
    requestClose: () => {
      // Closing an already-closed menu would steal focus back to its trigger.
      if (this.interaction.isExpanded) {
        this.interaction.closeMenu();
      }
    },
    // The bridge needs a host-DOM anchor rather than the portaled panel.
    getElement: () => this.interaction.triggerElement,
    getListboxId: () => this.listboxId,
    isStaticModal: () =>
      this.presenter.isStatic && this.presenter.overlayIsModal,
    shouldSuppressEntryCount: () =>
      this.presenter.shouldActivateSelected ||
      this.presenter.shouldAutoActivateFirst,
  });

  engine = this.host.engine;
  feedback = this.host.feedback;
  listbox = this.host.listbox;
  announcer = this.host.announcer;

  presenter: VariantPresenter = new VariantPresenter({
    getArgs: () => this.args,
    engine: this.engine,
    shouldRenderInModal: (modalForMobile) =>
      this.menu.shouldRenderInModal(modalForMobile),
    isExpanded: () => this.interaction.isExpanded,
    activeListboxId: () => this.activeListboxId,
  });

  /** Records eligibility after render; the session latch survives later presentation changes. */
  watchSelectionStrip = modifier(() => {
    const eligible = this.presenter.selectionStripEligible;
    const session = this.interaction.session;
    const check = schedule("afterRender", () => {
      if (
        !this.isDestroying &&
        eligible &&
        this.interaction.session === session
      ) {
        this.interaction.latchSelectionStrip();
      }
    });
    return () => cancel(check);
  });

  #listboxId = `d-select-listbox-${guidFor(this)}`;

  constructor(owner: Owner, args: DSelectSignature["Args"]) {
    super(owner, args);
    this.interaction = new InteractionCoordinator({
      engine: this.engine,
      presenter: this.presenter,
      announcer: this.announcer,
      capabilities: this.capabilities,
      onShow: () => this.args.onShow?.(),
      onClose: () => this.args.onClose?.(),
      isMultiple: () => this.args.multiple,
    });
    associateDestroyableChild(this, this.host);
    associateDestroyableChild(this, this.interaction);
  }

  /** Stable id for the panel message describing cap-disabled options. */
  get limitId(): string {
    return `${this.#listboxId}-limit`;
  }

  /** Description for every display-only trigger, merged with consumer help. */
  get triggerDescribedBy(): string | undefined {
    return this.host.describedBy(
      this.presenter.describeHeldLabels && this.engine.hasValue
        ? this.heldLabelsId
        : undefined,
      this.args.describedBy
    );
  }

  /** Stable association for the complete list of held labels. */
  get heldLabelsId(): string {
    return `${this.#listboxId}-held-labels`;
  }

  /**
   * The held values resolved once, for both the trigger chips and the held-labels description.
   * Separate lookups race: one landing re-renders the other, which aborts its own request.
   */
  @cached
  get heldSelection(): TrackedAsyncData<
    readonly SelectDescriptor[] | undefined
  > {
    return new TrackedAsyncData(this.host.resolveMulti(this.args.value));
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
    return `d-select-selection-${guidFor(this)}`;
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
      !element.hasAttribute("disabled") ||
        this.args.disabled != null ||
        this.presenter.isDisabled
    );
  }

  /** Returns strip focus to the connected query, or the static modal's options. */
  @action
  focusAfterStrip(): void {
    if (this.interaction.filterInput?.isConnected) {
      this.interaction.focusInput();
    } else {
      this.listbox.focusFirstOption();
    }
  }

  @action
  onFilterInput(event: Event): void {
    this.engine.setFilter((event.target as HTMLInputElement).value);
  }

  <template>
    <DMenu
      aria-busy={{if this.engine.pending "true"}}
      aria-controls={{this.presenter.triggerRootControls}}
      aria-describedby={{unless
        this.presenter.isDesktopTypeahead
        this.triggerDescribedBy
      }}
      aria-disabled={{this.presenter.triggerRootDisabled}}
      aria-haspopup={{this.presenter.triggerRootHasPopup}}
      aria-invalid={{unless
        this.presenter.isDesktopTypeahead
        (if @invalid "true")
      }}
      aria-label={{this.presenter.triggerRootLabel}}
      aria-readonly={{this.presenter.triggerRootReadonly}}
      class="d-select"
      data-select-id={{this.listboxId}}
      data-unresolved={{if this.presenter.hasUnresolvedSelection "true"}}
      {{! Desktop typeahead owns the field id on its input; every other surface needs it on
        the root because no trigger input renders there. }}
      id={{unless this.presenter.isDesktopTypeahead @id}}
      role={{this.presenter.triggerRootRole}}
      tabindex={{this.presenter.triggerRootTabIndex}}
      ...attributes
      {{! The d-select__content class floors the overlay min-width in CSS: matchTriggerWidth pins
        it to the trigger, which is unusably narrow for a compact icon-only trigger, and the
        min-width floor overrides that (it also gives the windowed option list a real width). }}
      @ariaLabel={{this.presenter.ariaLabelText}}
      @contentClass="d-select__content"
      @contentRole={{this.presenter.panelContentRole}}
      {{! DMenu vetoes its own trigger open while locked, reactively. Keyboard/edit open + all
        mutate paths are gated separately in this component (they are not DMenu listeners). }}
      @disabled={{this.presenter.isLocked}}
      @focusTarget={{this.interaction.focusTarget}}
      @identifier={{@identifier}}
      {{! The panel is portaled away from the trigger, so Tab follows the portal's place in the
        document instead of the field's. Both directions need it, for different variants: the
        panel-searchable trigger keeps its controller INSIDE the panel, so Tab out of it must
        continue from the trigger; every variant can render a control in the panel (a footer block,
        the error state's retry), which nothing would otherwise lead into. Containment is the
        wrong tool for either — the desktop panel is a non-modal dialog, dismissed by clicking
        outside, so Tab is meant to leave it.

        Ungated: a panel with nothing focusable in it is unaffected in both directions, so a
        plain list still lets Tab pass over the widget and is still read with the arrow keys.
        Inert on mobile, where the overlay is a DModal that owns its own containment. }}
      @inlineTabOrder={{true}}
      @matchTriggerWidth={{true}}
      @modalForMobile={{true}}
      @offset={{@offset}}
      @onClose={{this.interaction.handleClose}}
      {{! The overlay is sized by its positioning, which lands after the windowed list has
        already measured itself against an unsized overlay. }}
      @onPositioned={{this.listbox.remeasureListbox}}
      @onRegisterApi={{this.interaction.registerMenu}}
      @onShow={{this.interaction.handleShow}}
      @placement={{@placement}}
      @trapTab={{false}}
      @triggerClass={{this.presenter.triggerClass}}
      {{! Desktop typeahead puts ARIA and keyboard behavior on its input; other surfaces use
        the root. }}
      @triggerComponent={{dElement "div"}}
      {{! Typeahead: keep DMenu's default click-to-open (the whole trigger root opens the
        overlay) but disable close-on-click so clicking the already-open trigger/input does
        not toggle it shut, and focus the input on open. Resetting the query is not scoped
        here — every variant clears on close, inside the interaction coordinator's close
        handler. }}
      @untriggers={{if
        this.presenter.isTypeahead
        this.interaction.emptyTriggers
      }}
      {{this.host.selectionHooks}}
      {{on "keydown" this.interaction.handleControllerKeydown capture=true}}
      {{on "keydown" this.interaction.handleTriggerRootKeydown}}
      {{! eslint-disable-next-line ember/template-no-pointer-down-event-binding }}
      {{on "mousedown" this.interaction.preventTriggerBlur}}
      {{didInsert this.interaction.registerStaticController}}
      {{didInsert this.assertDisabledIsAnArg}}
    >
      <:trigger as |menuArgs|>
        {{! Resolve the raw @value (stable identity) rather than engine.value, so this
          async context does not churn each render; a content-only skeleton shows while
          it resolves, so a bare id never flashes. }}
        <TriggerFrame
          @caret={{this.presenter.caretIcon}}
          @clearLabel={{this.presenter.clearLabel}}
          @icon={{this.presenter.icon}}
          @onClear={{this.interaction.handleClear}}
          @onLabelActivate={{this.interaction.focusFromLabel}}
          @pending={{this.engine.pending}}
          @showCaret={{this.presenter.showCaret}}
          @showClear={{this.presenter.showClear}}
        >
          {{#if @multiple}}
            <MultiChips
              @closeMenu={{menuArgs.close}}
              @composeDescribedBy={{this.host.describedBy}}
              @describedBy={{this.triggerDescribedBy}}
              @editing={{this.interaction.queryActive}}
              @engine={{this.engine}}
              @expanded={{menuArgs.expanded}}
              @focusChip={{this.interaction.focusChip}}
              @focusInput={{this.interaction.focusInput}}
              @hasSelectionBlock={{has-block "selection"}}
              @hasSelectionLoadingBlock={{has-block "selectionLoading"}}
              @hasUnresolvedBlock={{has-block "unresolved"}}
              @id={{@id}}
              @invalid={{@invalid}}
              @listboxId={{this.activeListboxId}}
              @onBlur={{this.interaction.handleTriggerBlur}}
              @onEdit={{this.interaction.beginQuery}}
              @onInputKeydown={{this.interaction.handleInputKeydown}}
              @onPaste={{this.host.handlePaste}}
              @onRegisterChipRoving={{this.interaction.registerChipRoving}}
              @pending={{this.engine.pending}}
              @presenter={{this.presenter}}
              @registerInput={{this.interaction.registerTriggerInput}}
              @selection={{this.heldSelection}}
              @shouldCorrectKeyboardOcclusion={{this.interaction.shouldCorrectKeyboardOcclusion}}
              @shouldSelectOnFocus={{this.interaction.shouldSelectOnFocus}}
              @showMenu={{menuArgs.show}}
              @value={{@value}}
            >
              <:selection as |item|>{{yield
                  item
                  this.engine.resolvedOptions
                  to="selection"
                }}</:selection>
              <:selectionLoading>{{yield
                  to="selectionLoading"
                }}</:selectionLoading>
              <:unresolved as |item|>{{yield
                  item
                  this.engine.resolvedOptions
                  to="unresolved"
                }}</:unresolved>
            </MultiChips>
          {{else}}
            <SingleTriggerDisplay
              @closeMenu={{menuArgs.close}}
              @composeDescribedBy={{this.host.describedBy}}
              @describedBy={{@describedBy}}
              @editing={{this.interaction.queryActive}}
              @engine={{this.engine}}
              @expanded={{menuArgs.expanded}}
              @hasSelectionBlock={{has-block "selection"}}
              @hasSelectionLoadingBlock={{has-block "selectionLoading"}}
              @hasUnresolvedBlock={{has-block "unresolved"}}
              @id={{@id}}
              @invalid={{@invalid}}
              @listboxId={{this.activeListboxId}}
              @onBlur={{this.interaction.handleTriggerBlur}}
              @onEdit={{this.interaction.beginQuery}}
              @onFocus={{this.interaction.handleTriggerFocus}}
              @onInputKeydown={{this.interaction.handleInputKeydown}}
              @onPaste={{this.host.handlePaste}}
              @pending={{this.engine.pending}}
              @placeholder={{this.presenter.placeholder}}
              @presenter={{this.presenter}}
              @registerInput={{this.interaction.registerTriggerInput}}
              @resolveSelection={{this.host.resolveSingle}}
              @selectionId={{this.selectionId}}
              @shouldCorrectKeyboardOcclusion={{this.interaction.shouldCorrectKeyboardOcclusion}}
              @shouldSelectOnFocus={{this.interaction.shouldSelectOnFocus}}
              @showMenu={{menuArgs.show}}
              @triggerFocused={{this.interaction.triggerFocused}}
              @value={{@value}}
            >
              <:selection as |item|>{{yield
                  item
                  this.engine.resolvedOptions
                  to="selection"
                }}</:selection>
              <:selectionLoading>{{yield
                  to="selectionLoading"
                }}</:selectionLoading>
              <:unresolved as |item|>{{yield
                  item
                  this.engine.resolvedOptions
                  to="unresolved"
                }}</:unresolved>
            </SingleTriggerDisplay>
          {{/if}}
        </TriggerFrame>
      </:trigger>

      <:content as |menuArgs|>
        <div
          class="d-select__panel"
          data-select-id={{this.listboxId}}
          {{on "focusout" this.interaction.handlePanelFocusOut}}
          {{this.watchSelectionStrip}}
          {{this.host.watchLoadContext}}
          {{didInsert
            this.feedback.trackLoadFeedback
            this.engine.serverPending
            this.engine.serverQueryPending
          }}
          {{didUpdate
            this.feedback.trackLoadFeedback
            this.engine.serverPending
            this.engine.serverQueryPending
          }}
          {{willDestroy this.feedback.releaseLoadFeedback}}
        >
          {{#if this.presenter.isPanelSearchable}}
            <DFilterInput
              aria-autocomplete="list"
              aria-controls={{this.activeListboxId}}
              aria-expanded="true"
              {{! The disclosure trigger hands focus straight here on open, so this is the first
                thing a reader meets. A placeholder is a last-resort name source that screen
                readers treat inconsistently — name it after the field it narrows. }}
              aria-label={{this.presenter.ariaLabelText}}
              autocomplete="off"
              class="d-select__filter"
              placeholder={{this.presenter.searchPlaceholderText}}
              role="combobox"
              @filterAction={{this.onFilterInput}}
              @icons={{hash left="magnifying-glass"}}
              @value={{this.engine.filter}}
              {{on
                "keydown"
                this.interaction.handleControllerKeydown
                capture=true
              }}
              {{on "paste" this.host.handlePaste}}
              {{didInsert this.interaction.captureFilter}}
            />
          {{else if this.presenter.isMobileTypeahead}}
            {{! Mobile: the query input lives inside the modal (an external host input can't
              function behind an aria-modal). No aria-owns (input + listbox share the modal
              subtree); no blur-close (the modal owns dismissal). }}
            <ComboboxQueryInput
              class="d-select__filter"
              @disabled={{this.presenter.isDisabled}}
              @editing={{this.interaction.queryActive}}
              @engine={{this.engine}}
              @expanded={{menuArgs.expanded}}
              @label={{this.presenter.ariaLabelText}}
              @listboxId={{this.activeListboxId}}
              @onEdit={{this.interaction.beginQuery}}
              @onOpen={{menuArgs.show}}
              @onRequestClose={{menuArgs.close}}
              @placeholder={{this.presenter.searchPlaceholderText}}
              @readonly={{this.presenter.isReadonly}}
              @registerInput={{this.interaction.captureFilter}}
              {{on "paste" this.host.handlePaste}}
              {{keepAboveKeyboard
                this.interaction.shouldCorrectKeyboardOcclusion
              }}
              {{on
                "keydown"
                this.interaction.handleControllerKeydown
                capture=true
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
                class="d-select__limit"
                id={{this.limitId}}
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

          {{#if this.interaction.showSelectionStrip}}
            <SelectionStrip
              @engine={{this.engine}}
              @focusFallback={{this.focusAfterStrip}}
              @focusStrip={{this.interaction.focusStrip}}
              @hasSelectionBlock={{has-block "selection"}}
              @hasUnresolvedBlock={{has-block "unresolved"}}
              @locked={{this.presenter.isLocked}}
              @onRegisterRoving={{this.interaction.registerStripRoving}}
              @onResize={{this.listbox.remeasureListbox}}
              @resolveSelection={{this.host.resolveMulti}}
              @returnToInput={{if
                this.presenter.isDesktopTypeahead
                this.interaction.focusInput
              }}
              @value={{@value}}
            >
              <:selection as |item|>{{yield
                  item
                  this.engine.resolvedOptions
                  to="selection"
                }}</:selection>
              <:unresolved as |item|>{{yield
                  item
                  this.engine.resolvedOptions
                  to="unresolved"
                }}</:unresolved>
            </SelectionStrip>
          {{/if}}

          {{#if this.engine.belowMinChars}}
            {{! Below the minimum query length: no source call (no request, no skeleton flash),
              and the truthy-empty-array routing / stray create-row are sidestepped by not
              rendering the list at all. The hint is announced through the a11y service (see announceMinChars);
              the visible node stays a status region for sighted users. }}
            <div
              class="d-select__min-chars"
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
            <SelectOptions
              @announcer={{this.announcer}}
              @engine={{this.engine}}
              @feedback={{this.feedback}}
              @filterInput={{this.interaction.filterInput}}
              @hasEmptyBlock={{has-block "empty"}}
              @hasErrorBlock={{has-block "error"}}
              @hasLoadingItemBlock={{has-block "loadingItem"}}
              @listbox={{this.listbox}}
              @loadListContent={{this.host.loadListContent}}
              @multiple={{@multiple}}
              @noResultsLabel={{@noResultsLabel}}
              @presenter={{this.presenter}}
            >
              <:body as |items _content modifiers|>
                <WindowedOptionList
                  @announcer={{this.announcer}}
                  @engine={{this.engine}}
                  @hasGroupHeaderBlock={{has-block "groupHeader"}}
                  @hasItemBlock={{has-block "item"}}
                  @hasLoadingItemBlock={{has-block "loadingItem"}}
                  @items={{items}}
                  @label={{this.presenter.ariaLabelText}}
                  @limitId={{this.limitId}}
                  @listbox={{this.listbox}}
                  @listboxId={{this.listboxId}}
                  @modifiers={{modifiers}}
                  @multiple={{@multiple}}
                  @onOptionMousedown={{this.interaction.preventPointerBlur}}
                  @presenter={{this.presenter}}
                  @selectedIcon={{@selectedIcon}}
                >
                  <:item as |item|>{{yield
                      item
                      this.engine.resolvedOptions
                      to="item"
                    }}</:item>
                  <:groupHeader as |item|>{{yield
                      item
                      this.engine.resolvedOptions
                      to="groupHeader"
                    }}</:groupHeader>
                  <:loadingItem>{{yield to="loadingItem"}}</:loadingItem>
                </WindowedOptionList>
              </:body>
              <:loadingItem>{{yield to="loadingItem"}}</:loadingItem>
              <:empty>{{yield to="empty"}}</:empty>
              <:error as |error retry|>{{yield error retry to="error"}}</:error>
            </SelectOptions>
          {{/if}}
          {{#if (has-block "footer")}}
            {{! A labeled region pinned below the list (a sibling of the listbox, never inside it).
              Keyboard-reachable via float-kit's Tab-forward; a desktop focus-out closes the menu. }}
            <div
              aria-label={{i18n "d_select.footer_label"}}
              class="d-select__footer"
              role="group"
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
                this.engine.resolvedOptions
                to="footer"
              }}
            </div>
          {{/if}}
        </div>
      </:content>
    </DMenu>
    {{#if this.presenter.describeHeldLabels}}
      {{#if this.engine.hasValue}}
        <DAsyncContent @asyncData={{this.heldSelection}}>
          <:content as |chips|>
            <ul class="sr-only" id={{this.heldLabelsId}}>
              {{#each chips key="key" as |chip|}}
                <li>{{this.engine.getSelectionLabel chip.item}}</li>
              {{/each}}
            </ul>
          </:content>
        </DAsyncContent>
      {{/if}}
    {{/if}}
  </template>
}
