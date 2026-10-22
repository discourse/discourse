import Component from "@glimmer/component";
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
import { hasContentPluginApiCallbacks } from "discourse/select-kit/lib/plugin-api";
import type A11yService from "discourse/services/a11y";
import { eq } from "discourse/truth-helpers";
import DFilterInput from "discourse/ui-kit/d-filter-input";
import SelectHost, {
  type SelectHostArgs,
} from "discourse/ui-kit/select/-internals/coordinators/select-host";
import SelectListInteraction from "discourse/ui-kit/select/-internals/coordinators/select-list-interaction";
import SelectListPresenter from "discourse/ui-kit/select/-internals/coordinators/select-list-presenter";
import type { SelectResolvedOptions } from "discourse/ui-kit/select/-internals/engine/customizations";
import SelectOptions from "discourse/ui-kit/select/-internals/parts/select-options";
import SelectionStrip from "discourse/ui-kit/select/-internals/parts/selection-strip";
import StaticOptionList from "discourse/ui-kit/select/-internals/parts/static-option-list";
import WindowedOptionList from "discourse/ui-kit/select/-internals/parts/windowed-option-list";
import type {
  SelectItem,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

/** Live state shared by the pinned list header and footer. */
export interface SelectListState {
  /** The current search query. */
  filter: string;
  /** Held values in selection order. */
  value: SelectValue;
  /** Whether any values are held. */
  hasValue: boolean;
  /** Source result count, when known. */
  total: number | undefined;
  /** Number of source options loaded so far. */
  loadedCount: number;
  /** Selection cap, or null when uncapped. */
  maximum: number | null;
  /** Advisory minimum selection size. */
  minimum: number;
  /** Whether the selection reached its cap. */
  atMaximum: boolean;
  /** Whether the selection is below its advisory minimum. */
  belowMinimum: boolean;
  /** Remaining selection capacity, when capped. */
  remaining: number | undefined;
}

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
    /** Reactive source inputs; replacing the object or an entry reloads the list. */
    loadContext?: SelectHostArgs["loadContext"];
    /** Local filtering fields or predicate. */
    filterBy?: SelectHostArgs["filterBy"];
    /** Identity field; omit for object values. */
    valueField?: string;
    /** Fallback display-label field. */
    labelField?: string;
    /** Already resolved held items. */
    valueItems?: SelectHostArgs["valueItems"];
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
    /** Virtualizes and paginates by default; false mounts a short first page in normal flow. */
    virtualized?: boolean;
    /** Omits held options from results without reloading. */
    hideSelected?: boolean;
    /** Hard selection cap. */
    maximum?: number;
    /** Advisory selection minimum. */
    minimum?: number;
    /** Customization family, fixed at construction. */
    kind?: string;
    /** Declares live recipe options; core option keys remain reserved. */
    kindOptions?: Record<string, unknown>;
    /** Call-site customization identity. */
    identifier?: string;
    /** Recipe context supplied to customizations. */
    kindContext?: object;
    /** Call-site context supplied to customizations. */
    instanceContext?: object;
    /** Accessible name for the search and list. */
    label?: string;
    /** Search placeholder text. */
    placeholder?: string;
    /** Label shown when a nonempty query returns no results. */
    noResultsLabel?: string;
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
    ];
    /** Custom held-chip content. */
    selection?: [
      /** Held item. */ item: SelectItem,
      /** Resolved options. */ options: SelectResolvedOptions,
    ];
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
  });

  #listboxId = `d-select-listbox-${guidFor(this)}`;

  /**
   * TODO (select-kit-replacement-cleanup): Legacy content callbacks read the root while the list
   * builds, so the list waits one render for it only when such a callback targets this select.
   */
  #needsBridgeAnchor =
    !!this.args.kind && hasContentPluginApiCallbacks([this.args.kind]);

  constructor(owner: Owner, args: DSelectListSignature["Args"]) {
    super(owner, args);
    this.interaction = new SelectListInteraction({
      engine: this.engine,
      presenter: this.presenter,
      announcer: this.announcer,
      listbox: this.listbox,
    });
    associateDestroyableChild(this, this.host);
    associateDestroyableChild(this, this.interaction);
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

  @action
  onFilterInput(event: Event): void {
    if (!this.presenter.isLocked) {
      this.engine.setFilter((event.target as HTMLInputElement).value);
    }
  }

  <template>
    <div
      class="d-select --list"
      data-select-id={{this.listboxId}}
      ...attributes
      {{this.interaction.registerRoot}}
      {{this.host.selectionHooks}}
      {{this.host.watchLoadContext}}
      {{this.interaction.watchCursor}}
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
      <DFilterInput
        aria-autocomplete="list"
        aria-busy={{if this.engine.serverPending "true"}}
        aria-controls={{this.activeListboxId}}
        aria-describedby={{@describedBy}}
        aria-expanded={{if this.activeListboxId "true"}}
        aria-invalid={{if @invalid "true"}}
        aria-label={{this.presenter.ariaLabelText}}
        class="d-select__filter"
        disabled={{this.presenter.isDisabled}}
        id={{@id}}
        placeholder={{this.presenter.placeholder}}
        readonly={{this.presenter.isReadonly}}
        role="combobox"
        @filterAction={{this.onFilterInput}}
        @icons={{hash left="magnifying-glass"}}
        @value={{this.engine.filter}}
        {{didInsert this.interaction.registerFilter}}
        {{on "keydown" this.interaction.handleInputKeydown capture=true}}
        {{on "paste" this.host.handlePaste}}
      />
      {{#if this.presenter.limitMessage}}
        <div
          class="d-select__limit"
          id={{this.limitId}}
          role={{if this.interaction.focused "status"}}
          {{didInsert
            this.announcer.announceLimitOnEntry
            this.presenter.limitMessage
          }}
          {{didUpdate
            this.interaction.reportLimit
            this.presenter.limitMessage
            this.interaction.focused
          }}
        >{{this.presenter.limitMessage}}</div>
      {{/if}}
      {{#if this.engine.hasValue}}
        <SelectionStrip
          @engine={{this.engine}}
          @focusFallback={{this.interaction.focusInput}}
          @focusStrip={{this.interaction.focusStrip}}
          @hasSelectionBlock={{has-block "selection"}}
          @hasUnresolvedBlock={{has-block "unresolved"}}
          @locked={{this.presenter.isLocked}}
          @onRegisterRoving={{this.interaction.registerStripRoving}}
          @onResize={{this.listbox.remeasureListbox}}
          @resolveSelection={{this.host.resolveMulti}}
          @returnToInput={{this.interaction.focusInput}}
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
      {{#let
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
        )
        as |state|
      }}
        {{#if (has-block "listHeader")}}
          <div class="d-select__list-header">{{yield
              state
              this.engine.resolvedOptions
              to="listHeader"
            }}</div>
        {{/if}}
        {{#if this.engine.belowMinChars}}
          <div
            class="d-select__min-chars"
            role={{if this.interaction.focused "status"}}
            {{didInsert
              this.announcer.announceMinCharsOnEntry
              this.engine.remainingMinChars
            }}
            {{didUpdate
              this.interaction.reportMinChars
              this.engine.remainingMinChars
              this.interaction.focused
            }}
          >{{i18n
              "d_select.min_chars"
              count=this.engine.remainingMinChars
            }}</div>
        {{else if this.renderOptions}}
          <SelectOptions
            @announcer={{this.announcer}}
            @engine={{this.engine}}
            @feedback={{this.feedback}}
            @filterInput={{this.interaction.filterInput}}
            @hasEmptyBlock={{has-block "empty"}}
            @hasErrorBlock={{has-block "error"}}
            @hasLoadingItemBlock={{false}}
            @hideEmptyQuery={{true}}
            @listbox={{this.listbox}}
            @loadListContent={{this.host.loadListContent}}
            @multiple={{true}}
            @noResultsLabel={{@noResultsLabel}}
            @onRegisterListbox={{this.interaction.registerListbox}}
            @onRegisterRoving={{this.interaction.registerRoving}}
            @presenter={{this.presenter}}
            @reportsActive={{this.interaction.focused}}
          >
            <:body as |items content modifiers|>
              {{#let
                (if (eq @virtualized false) StaticOptionList WindowedOptionList)
                as |Body|
              }}
                <Body
                  @announcer={{this.announcer}}
                  @engine={{this.engine}}
                  @hasGroupHeaderBlock={{false}}
                  @hasItemBlock={{has-block "item"}}
                  @hasLoadingItemBlock={{false}}
                  @hideSelectionMarker={{@hideSelected}}
                  @items={{items}}
                  @label={{this.presenter.ariaLabelText}}
                  @limitId={{this.limitId}}
                  @listbox={{this.listbox}}
                  @listboxId={{this.listboxId}}
                  @modifiers={{modifiers}}
                  @multiple={{true}}
                  @onOptionMousedown={{this.interaction.preventPointerBlur}}
                  @presenter={{this.presenter}}
                  @selectedIcon={{@selectedIcon}}
                  @tabIndex={{-1}}
                >
                  <:item as |item|>{{yield
                      item
                      this.engine.resolvedOptions
                      to="item"
                    }}</:item>
                </Body>
              {{/let}}
            </:body>
            <:empty>{{yield to="empty"}}</:empty>
            <:error as |error retry|>{{yield error retry to="error"}}</:error>
          </SelectOptions>
        {{/if}}
        {{#if (has-block "footer")}}
          <div
            aria-label={{i18n "d_select.footer_label"}}
            class="d-select__footer"
            role="group"
          >
            {{yield state this.engine.resolvedOptions to="footer"}}
          </div>
        {{/if}}
      {{/let}}
    </div>
  </template>
}
