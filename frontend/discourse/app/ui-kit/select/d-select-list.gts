import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { associateDestroyableChild } from "@ember/destroyable";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import Owner, { getOwner } from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import { TrackedAsyncData } from "ember-async-data";
import { hasContentPluginApiCallbacks } from "discourse/select-kit/lib/plugin-api";
import type A11yService from "discourse/services/a11y";
import type { CapabilitiesService } from "discourse/services/capabilities";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import SelectHost, {
  type SelectHostArgs,
} from "discourse/ui-kit/select/-internals/coordinators/select-host";
import SelectListInteraction from "discourse/ui-kit/select/-internals/coordinators/select-list-interaction";
import SelectListPresenter from "discourse/ui-kit/select/-internals/coordinators/select-list-presenter";
import type { SelectResolvedOptions } from "discourse/ui-kit/select/-internals/engine/customizations";
import { assertNoRemovedTextArgs } from "discourse/ui-kit/select/-internals/engine/select-texts";
import { legacySelectKitIdentifiers } from "discourse/ui-kit/select/-internals/modify-select-kit-bridge";
import MultiChips from "discourse/ui-kit/select/-internals/parts/multi-chips";
import SelectPanel, {
  type SelectPanelState,
} from "discourse/ui-kit/select/-internals/parts/select-panel";
import StaticOptionList from "discourse/ui-kit/select/-internals/parts/static-option-list";
import WindowedOptionList from "discourse/ui-kit/select/-internals/parts/windowed-option-list";
import type {
  SelectCoreTexts,
  SelectDescriptor,
  SelectItem,
  SelectItemRow,
  SelectKindTexts,
  SelectTextWrapper,
} from "discourse/ui-kit/select/select-engine";

/** Live state yielded to the list's `:listHeader` and `:footer` blocks. */
export type SelectListState = SelectPanelState;

/** Public API for a persistent multi-select with an optional static list body. */
interface DSelectListSignature {
  Args: {
    /** Controlled held values; this component always selects multiple items. */
    value?: readonly unknown[];
    /** Receives the replacement values, resolved items and change metadata. */
    onChange?: (
      next: unknown[],
      items: SelectItem[],
      change: Parameters<NonNullable<SelectHostArgs["onChange"]>>[2]
    ) => void;
    /** Local options, or a function of resolved options. */
    items?: SelectHostArgs["items"];
    /** Async query source, optionally paginating with total or hasMore. */
    load?: SelectHostArgs["load"];
    /** Reactive source inputs; a changed entry reloads the list, and arrays compare by their elements. */
    loadContext?: SelectHostArgs["loadContext"];
    /** Local filtering fields or predicate. */
    filterBy?: SelectHostArgs["filterBy"];
    /** Identity field; omit for object values. */
    valueField?: string;
    /** Maps an id to the key that decides identity; ids match exactly without it. Read once. */
    normalizeKey?: SelectHostArgs["normalizeKey"];
    /** Fallback display-label field. */
    labelField?: string;
    /** Already resolved held items. */
    valueItems?: SelectHostArgs["valueItems"];
    /** Resolves one held value; used when `@resolveValues` is absent. */
    resolveValue?: SelectHostArgs["resolveValue"];
    /** Resolves held values in one batch. */
    resolveValues?: SelectHostArgs["resolveValues"];
    /** Whether unmatched queries can create an item. */
    allowCreate?: SelectHostArgs["allowCreate"];
    /** Builds an item from the current query. */
    createItem?: SelectHostArgs["createItem"];
    /** Builds the fallback for an unavailable held value. */
    createUnresolvedItem?: SelectHostArgs["createUnresolvedItem"];
    /** Parses pasted text into a selection batch. */
    parsePaste?: SelectHostArgs["parsePaste"];
    /** Query debounce in milliseconds; true uses the shared input delay. */
    debounce?: boolean | number;
    /** Minimum query length before calling the source. */
    minChars?: number;
    /** Optional server row ceiling with a filter-to-narrow hint. Uncapped by default. */
    maxLoaded?: number;
    /** Virtualizes and paginates by default; false mounts a short first page in normal flow. */
    virtualized?: boolean;
    /** Omits held options from results without reloading. */
    hideSelected?: boolean;
    /** Hard selection cap; false means no cap. Invalid numbers warn in development. */
    maximum?: number | false;
    /** Advisory selection minimum. */
    minimum?: number;
    /** Skips a passed `:footer` block; see `DSelect`'s `@suppressFooter`. */
    suppressFooter?: boolean;
    /** Customization family, fixed at construction. */
    kind?: string;
    /**
     * Temporary compatibility alias for the deprecated modifySelectKit bridge and legacy CSS;
     * not a customization key.
     */
    legacyKind?: string | string[];
    /** Declares live recipe options; core option keys remain reserved. */
    kindOptions?: Record<string, unknown>;
    /**
     * Every text the select draws or speaks, by key: a translated string, `{ translationKey }`
     * for a translation, or a function of the text's values. Each entry merges over the recipe's
     * and the engine's defaults; `""` means the place shows nothing.
     */
    texts?: SelectCoreTexts;
    /**
     * A recipe's texts: defaults for engine texts and its own. A recipe built on another may pass
     * a list, lowest first, so its functions can read or defer to the inner recipe's entries (see
     * `SelectKindTexts`). Requires `@kind`; the recipe's own keys are fixed at construction.
     */
    kindTexts?: SelectKindTexts;
    /**
     * A recipe's final say over a text, run once on the result of every layer. Requires `@kind`;
     * keys are fixed at construction, and texts that name a control can't be wrapped.
     */
    kindTextWrappers?: Readonly<Record<string, SelectTextWrapper | undefined>>;
    /** Call-site customization identity. */
    identifier?: string;
    /** Recipe context supplied to customizations. */
    kindContext?: object;
    /** Call-site context supplied to customizations. */
    instanceContext?: object;
    /** A decorative trailing icon in the search field. */
    searchIcon?: string;
    /** Shows a status line, with a spinner, above the loading skeleton; off by default. */
    loadingStatus?: boolean;
    /** Native search-input id, for a label's for attribute. */
    id?: string;
    /** Additional search-input description ids. */
    describedBy?: string;
    /** Marks the search input invalid. */
    invalid?: boolean;
    /** Disables focus, editing and selection. */
    disabled?: boolean;
    /** Retains focusability while preventing edits and selection. */
    readonly?: boolean;
    /** Offers retry after a source error; defaults to true. */
    retryable?: boolean;
    /** Icon marking selected options. */
    selectedIcon?: string;
  };
  Element: HTMLDivElement;
  Blocks: {
    /** Custom option content. */
    item?: [
      /** Raw option. */ item: SelectItem,
      /** Resolved options. */ options: SelectResolvedOptions,
      /** What the row is beyond its item: `create` marks the create row. */
      row: SelectItemRow,
    ];
    /** Custom held-chip content. */
    selection?: [
      /** Held item. */ item: SelectItem,
      /** Resolved options. */ options: SelectResolvedOptions,
    ];
    /** Stands in for each held chip while held values resolve. */
    selectionLoading?: [];
    /** Content for unavailable held values. */
    unresolved?: [
      /** Fallback item. */ item: SelectItem,
      /** Resolved options. */ options: SelectResolvedOptions,
    ];
    /** Custom no-results content for a nonempty query. */
    empty?: [];
    /** Custom source-error content. */
    error?: [
      /** Rejection reason. */ error: Error,
      /** Reloads the source. */ retry: () => void,
    ];
    /** Pinned content between held chips and results, outside the listbox. */
    listHeader?: [
      /** Live list state. */ state: SelectListState,
      /** Resolved options. */ options: SelectResolvedOptions,
    ];
    /** Pinned content after results; dismissal belongs to the containing panel. */
    footer?: [
      /** Live list state. */ state: SelectListState,
      /** Resolved options. */ options: SelectResolvedOptions,
    ];
  };
}

/** Always-open searchable multi-select; focus and dismissal belong to its containing panel. */
export default class DSelectList extends Component<DSelectListSignature> {
  @service declare a11y: A11yService;
  @service declare capabilities: CapabilitiesService;

  interaction: SelectListInteraction;

  host: SelectHost = new SelectHost({
    owner: getOwner(this),
    getA11y: () => this.a11y,
    getArgs: () => ({ ...this.args, onChange: this.handleChange }),
    getPresenter: () => this.presenter,
    getMultiple: () => true,
    isLive: () => !this.isDestroying,
    session: () => this.interaction.session,
    clearQuery: () => this.engine.setFilter(""),
    requestClose: () => {},
    getElement: () => this.interaction.root,
    getListboxId: () => this.listboxId,
    isStaticModal: () => false,
    shouldSuppressEntryCount: () => false,
    canReport: () => this.interaction.canReport(),
  });

  engine = this.host.engine;
  announcer = this.host.announcer;
  feedback = this.host.feedback;
  listbox = this.host.listbox;

  presenter: SelectListPresenter = new SelectListPresenter({
    engine: this.engine,
    getArgs: () => this.args,
    canSeed: () => this.interaction.canSeed,
    usesDirectFocus: () => this.interaction.usesDirectFocus,
  });

  #listboxId = `d-select-listbox-${guidFor(this)}`;

  /**
   * TODO (select-kit-replacement-cleanup): Legacy content callbacks read the root while the list
   * builds, so the list waits one render for it only when such a callback targets this select.
   */
  #needsBridgeAnchor = hasContentPluginApiCallbacks(
    legacySelectKitIdentifiers(this.engine)
  );

  constructor(owner: Owner, args: DSelectListSignature["Args"]) {
    super(owner, args);
    assertNoRemovedTextArgs("DSelectList", args);
    this.interaction = new SelectListInteraction({
      engine: this.engine,
      presenter: this.presenter,
      announcer: this.announcer,
      listbox: this.listbox,
      platform: this.capabilities,
    });
    associateDestroyableChild(this, this.host);
    associateDestroyableChild(this, this.interaction);
  }

  @cached
  get heldSelection(): TrackedAsyncData<
    readonly SelectDescriptor[] | undefined
  > {
    return new TrackedAsyncData(this.host.resolveMulti(this.args.value));
  }

  get listboxId(): string {
    return this.#listboxId;
  }

  get limitId(): string {
    return `${this.listboxId}-limit`;
  }

  get activeListboxId(): string | undefined {
    return this.interaction.listboxElement ? this.listboxId : undefined;
  }

  get renderOptions(): boolean {
    return !this.#needsBridgeAnchor || !!this.interaction.root;
  }

  @action
  handleChange(
    ...[next, items, change]: Parameters<
      NonNullable<SelectHostArgs["onChange"]>
    >
  ): void {
    // The host engine is always multi; narrow its arity-union at this boundary.
    this.args.onChange?.(next as unknown[], items as SelectItem[], change);
  }

  <template>
    <div
      {{! TODO (select-kit-replacement-cleanup): Retain legacy root classes during rollout. }}
      class={{dConcatClass "d-select" "--list" this.engine.legacyKinds}}
      data-select-id={{this.listboxId}}
      data-selection-removal="panel-chips"
      ...attributes
      {{this.interaction.registerRoot}}
      {{this.host.selectionHooks}}
      {{this.host.watchLoadContext}}
      {{this.interaction.watchCursor}}
      {{didInsert
        this.feedback.trackLoadFeedback
        (or
          this.engine.serverPending
          (and (eq @virtualized false) this.engine.serverAwaitingFirstPage)
        )
        this.engine.serverQueryPending
      }}
      {{didUpdate
        this.feedback.trackLoadFeedback
        (or
          this.engine.serverPending
          (and (eq @virtualized false) this.engine.serverAwaitingFirstPage)
        )
        this.engine.serverQueryPending
      }}
      {{willDestroy this.feedback.releaseLoadFeedback}}
    >
      <SelectPanel
        @announcer={{this.announcer}}
        @body={{if (eq @virtualized false) StaticOptionList WindowedOptionList}}
        @engine={{this.engine}}
        @feedback={{this.feedback}}
        @filterInput={{this.interaction.filterInput}}
        @focusFallback={{this.interaction.focusInput}}
        @focusStrip={{this.interaction.focusStrip}}
        @hasEmptyBlock={{has-block "empty"}}
        @hasErrorBlock={{has-block "error"}}
        @hasFooterBlock={{and (has-block "footer") (not @suppressFooter)}}
        @hasGroupFooterBlock={{false}}
        @hasGroupHeaderBlock={{false}}
        @hasItemBlock={{has-block "item"}}
        @hasListHeaderBlock={{has-block "listHeader"}}
        @hasSelectionBlock={{has-block "selection"}}
        @hasSkeletonItemBlock={{false}}
        @hasUnresolvedBlock={{has-block "unresolved"}}
        @hideEmptyQuery={{true}}
        @hideSelectionMarker={{@hideSelected}}
        @hintRole={{if this.interaction.focused "status"}}
        @label={{this.presenter.ariaLabelText}}
        @limitId={{this.limitId}}
        @limitMessage={{this.presenter.limitMessage}}
        @listbox={{this.listbox}}
        @listboxId={{this.listboxId}}
        @loadListContent={{this.host.loadListContent}}
        @locked={{this.presenter.isLocked}}
        @multiple={{true}}
        @onOptionMousedown={{this.interaction.preventPointerBlur}}
        @onRegisterListbox={{this.interaction.registerListbox}}
        @onRegisterRoving={{this.interaction.registerRoving}}
        @onRegisterStripRoving={{this.interaction.registerStripRoving}}
        @onStripResize={{this.listbox.remeasureListbox}}
        @presenter={{this.presenter}}
        @renderOptions={{this.renderOptions}}
        @reportsActive={{this.interaction.focused}}
        @resolveSelection={{this.host.resolveMulti}}
        @selectedIcon={{@selectedIcon}}
        @state={{hash
          filter=this.engine.filter
          query=this.host.query
          pending=this.engine.serverPending
          showingSkeleton=this.feedback.showingSkeleton
          value=this.engine.value
          hasValue=this.engine.hasValue
          total=this.engine.total
          loadedCount=this.engine.loadedCount
          maximum=this.engine.maximum
          minimum=this.engine.minimum
          atMaximum=this.engine.atMaximum
          belowMinimum=this.engine.belowMinimum
          remaining=this.engine.remaining
        }}
        @staticBody={{eq @virtualized false}}
        @tabIndex={{-1}}
        @value={{@value}}
      >
        <:field>
          <MultiChips
            @ariaOwns={{false}}
            @closeMenu={{this.interaction.focusInput}}
            @composeDescribedBy={{this.host.describedBy}}
            @describedBy={{@describedBy}}
            @editing={{true}}
            @engine={{this.engine}}
            @expanded={{true}}
            @fieldRendersInput={{true}}
            @focusChip={{this.interaction.focusChip}}
            @focusInput={{this.interaction.focusInput}}
            @hasSelectionBlock={{has-block "selection"}}
            @hasSelectionLoadingBlock={{has-block "selectionLoading"}}
            @hasUnresolvedBlock={{has-block "unresolved"}}
            @id={{@id}}
            @invalid={{@invalid}}
            @label={{this.presenter.ariaLabelText}}
            @listboxId={{this.activeListboxId}}
            @onChipFocus={{this.interaction.clearActive}}
            @onEscape={{this.interaction.handleEscape}}
            @onInputKeydown={{this.interaction.handleInputKeydown}}
            @onPaste={{this.host.handlePaste}}
            @onRegisterChipRoving={{this.interaction.registerChipRoving}}
            @onResize={{this.listbox.remeasureListbox}}
            @pending={{this.engine.pending}}
            @placeholder={{this.presenter.searchPlaceholderText}}
            @presenter={{this.presenter}}
            @queryDisplay="always"
            @registerInput={{this.interaction.registerFilter}}
            @roleMode="search"
            @searchIcon={{this.engine.resolvedOptions.searchIcon}}
            @selection={{this.heldSelection}}
            @showMenu={{this.interaction.focusInput}}
            @tabPassthrough={{true}}
            @triggerChipsInteractive={{true}}
            @value={{@value}}
          >
            <:selection as |item|>
              {{~yield item this.engine.resolvedOptions to="selection"~}}
            </:selection>
            <:selectionLoading>
              {{~yield to="selectionLoading"~}}
            </:selectionLoading>
            <:unresolved as |item|>
              {{~yield item this.engine.resolvedOptions to="unresolved"~}}
            </:unresolved>
          </MultiChips>
        </:field>
        <:item as |item options row|>
          {{~yield item options row to="item"~}}
        </:item>
        <:selection as |item options|>
          {{~yield item options to="selection"~}}
        </:selection>
        <:unresolved as |item options|>
          {{~yield item options to="unresolved"~}}
        </:unresolved>
        <:empty>
          {{~yield to="empty"~}}
        </:empty>
        <:error as |error retry|>
          {{~yield error retry to="error"~}}
        </:error>
        <:listHeader as |state options|>
          {{~yield state options to="listHeader"~}}
        </:listHeader>
        <:footer as |state options|>
          {{~yield state options to="footer"~}}
        </:footer>
      </SelectPanel>
    </div>
  </template>
}
