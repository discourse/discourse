import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import type { DRovingFocusApi } from "discourse/ui-kit/modifiers/d-roving-focus";
import type LoadFeedbackTracker from "discourse/ui-kit/select/-internals/coordinators/load-feedback";
import type SelectAnnouncer from "discourse/ui-kit/select/-internals/coordinators/select-announcer";
import type { OptionsPresenter } from "discourse/ui-kit/select/-internals/coordinators/select-presenter-base";
import type WindowedListCoordinator from "discourse/ui-kit/select/-internals/coordinators/windowed-list-coordinator";
import type { SelectResolvedOptions } from "discourse/ui-kit/select/-internals/engine/customizations";
import SelectOptions, {
  type SelectListContent,
} from "discourse/ui-kit/select/-internals/parts/select-options";
import SelectionStrip from "discourse/ui-kit/select/-internals/parts/selection-strip";
import type WindowedOptionList from "discourse/ui-kit/select/-internals/parts/windowed-option-list";
import SelectEngine, {
  SelectDescriptor,
  SelectItem,
  type SelectItemRow,
  SelectLoadOptions,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";

/** Live state yielded to a select's `:listHeader` and `:footer` blocks. */
export interface SelectPanelState {
  /** The text in the search field right now. */
  filter: string;
  /**
   * The search the visible results are for. While a new search loads, the previous results stay
   * on screen and this keeps naming their search until the new results arrive.
   */
  query: string;
  /**
   * Whether results are loading: a new search, a reload or the next page. True from the moment
   * it starts (for a search, the keystroke), before any skeleton shows.
   */
  pending: boolean;
  /**
   * Whether skeleton rows stand in for the results, which happens once a search or the first
   * load runs past a short delay. While true, no results are on screen and `query` names the
   * last search that finished.
   */
  showingSkeleton: boolean;
  /** Held values in selection order, or the single held value. */
  value: SelectValue;
  /** Whether anything is held. */
  hasValue: boolean;
  /** The whole result-set size, or `undefined` when a paginating source has not reported one. */
  total: number | undefined;
  /** How many results are loaded so far. */
  loadedCount: number;
  /** The selection cap, or `null` when uncapped. */
  maximum: number | null;
  /** The advisory selection minimum (`0` means none). */
  minimum: number;
  /** Whether the selection reached its cap. */
  atMaximum: boolean;
  /** Whether the selection is below its advisory minimum. */
  belowMinimum: boolean;
  /** How many more items may be added, or `undefined` when uncapped. */
  remaining: number | undefined;
}

interface SelectPanelSignature<State> {
  Args: {
    /** The headless selection engine. */
    engine: SelectEngine;
    /** Presentation state for the option list. */
    presenter: OptionsPresenter;
    /** Loading feedback shared with the host. */
    feedback: LoadFeedbackTracker;
    /** The list controller shared with the host. */
    listbox: WindowedListCoordinator;
    /** Screen-reader announcements shared with the host. */
    announcer: SelectAnnouncer;
    /** Visible selection-limit text; omitted when the hint is hidden. */
    limitMessage?: string;
    /** Stable id for the selection-limit hint. */
    limitId: string;
    /** Live-region role for the limit and minimum-query hints; omitted while they should stay quiet. */
    hintRole?: "status";
    /** Whether to render held items above the results. */
    showSelectionStrip?: boolean;
    /** Focuses the host when the final held chip is removed. */
    focusFallback: () => void;
    /** Focuses a held chip by index. */
    focusStrip: (index: number) => boolean;
    /** Registers the held strip cursor with the host. */
    onRegisterStripRoving: (api: DRovingFocusApi | null) => void;
    /** Remeasures the results after the held strip changes size. */
    onStripResize: () => void;
    /** Resolves held items through the host cache. */
    resolveSelection: (
      value: unknown,
      options?: SelectLoadOptions
    ) =>
      | readonly SelectDescriptor[]
      | Promise<readonly SelectDescriptor[] | undefined>
      | undefined;
    /** Returns navigation from the held strip to the query input. */
    returnToInput?: () => void;
    /** Whether held items are protected from removal. */
    locked: boolean;
    /** Controlled held values in selection order. */
    value?: SelectValue;
    /** Whether the host is ready to render the option source. */
    renderOptions?: boolean;
    /** The static or windowed option-body component. */
    body: typeof WindowedOptionList;
    /** The host input controlling active-descendant focus. */
    filterInput: HTMLElement | null;
    /** Loads options while preserving host-specific resolved-query state. */
    loadListContent: (
      context: unknown,
      options?: SelectLoadOptions
    ) => SelectListContent | Promise<SelectListContent>;
    /** Suppresses an empty result state for an empty query. */
    hideEmptyQuery?: boolean;
    /** Preserves host focus when an option is pressed. */
    onOptionMousedown: (event: MouseEvent) => void;
    /** Reports listbox mounting and teardown to the host. */
    onRegisterListbox?: (element: HTMLElement | null) => void;
    /** Registers the results cursor with the host. */
    onRegisterRoving?: (api: DRovingFocusApi | null) => void;
    /** Whether the panel reports its states; a change re-announces the visible hints. */
    reportsActive?: boolean;
    /** Whether source loading retains a static option body. */
    staticBody?: boolean;
    /** Whether the option list accepts multiple values. */
    multiple?: boolean;
    /** Omits selection markers from result rows. */
    hideSelectionMarker?: boolean;
    /** Accessible name for the option list. */
    label?: string;
    /** Ids of the elements naming the option list, used instead of `label`. */
    labelledBy?: string;
    /** Stable id of the rendered listbox. */
    listboxId: string;
    /** Icon marking selected result rows. */
    selectedIcon?: string;
    /** Explicit tab index for the option body. */
    tabIndex?: number;
    /** Whether the host supplies the item block. */
    hasItemBlock: boolean;
    /** Whether the host supplies the groupHeader block. */
    hasGroupHeaderBlock: boolean;
    /** Whether the host supplies the groupFooter block. */
    hasGroupFooterBlock: boolean;
    /** Whether the host supplies the skeletonItem block. */
    hasSkeletonItemBlock: boolean;
    /** Whether the host supplies the selection block. */
    hasSelectionBlock: boolean;
    /** Whether the host supplies the unresolved block. */
    hasUnresolvedBlock: boolean;
    /** Whether the host supplies the empty block. */
    hasEmptyBlock: boolean;
    /** Whether the host supplies the error block. */
    hasErrorBlock: boolean;
    /** Whether the host supplies the listHeader block. */
    hasListHeaderBlock: boolean;
    /** Whether the host supplies the footer block. */
    hasFooterBlock: boolean;
    /** Host-built live state for the pinned header and footer. */
    state: State;
  };
  Blocks: {
    /** Optional search field sharing this panel with its results. */
    field?: [];
    /** Custom item content. */
    item?: [
      /** The rendered item. */ item: SelectItem,
      /** Resolved core and recipe options. */ options: SelectResolvedOptions,
      /** What the row is, beyond its item. */ row: SelectItemRow,
    ];
    /** Custom groupHeader content. */
    groupHeader?: [
      /** The rendered item. */ item: SelectItem,
      /** Resolved core and recipe options. */ options: SelectResolvedOptions,
    ];
    /** Custom groupFooter content. */
    groupFooter?: [
      /** The rendered item. */ item: SelectItem,
      /** Resolved core and recipe options. */ options: SelectResolvedOptions,
    ];
    /** Custom selection content. */
    selection?: [
      /** The rendered item. */ item: SelectItem,
      /** Resolved core and recipe options. */ options: SelectResolvedOptions,
    ];
    /** Custom unresolved content. */
    unresolved?: [
      /** The rendered item. */ item: SelectItem,
      /** Resolved core and recipe options. */ options: SelectResolvedOptions,
    ];
    /** Custom skeletonItem content. */
    skeletonItem?: [];
    /** Custom empty content. */
    empty?: [];
    /** Custom source-error content. */
    error?: [
      /** The source rejection. */ error: Error,
      /** Reloads the source. */ retry: () => void,
    ];
    /** Pinned listHeader content outside the listbox. */
    listHeader?: [
      /** Host-built live state. */ state: State,
      /** Resolved core and recipe options. */ options: SelectResolvedOptions,
    ];
    /** Pinned footer content outside the listbox. */
    footer?: [
      /** Host-built live state. */ state: State,
      /** Resolved core and recipe options. */ options: SelectResolvedOptions,
    ];
  };
}

/** Shared panel siblings; the host owns their root and search input. */
export default class SelectPanel<State> extends Component<
  SelectPanelSignature<State>
> {
  get resolvedOptions(): SelectResolvedOptions {
    return this.args.engine.resolvedOptions;
  }

  <template>
    {{yield to="field"}}
    {{#if @limitMessage}}
      {{! A pinned top zone (sibling of the list, above it), so the cap/floor hint never
        stacks with the footer or an error body. Announced through the a11y service (a mounted
        live region speaks unreliably); the node stays a status region for sighted users. }}
      <div
        class="d-select__limit"
        id={{@limitId}}
        role={{@hintRole}}
        {{didInsert @announcer.announceLimitOnEntry @limitMessage}}
        {{didUpdate @announcer.announceLimit @limitMessage @reportsActive}}
      >
        {{@limitMessage}}
      </div>
    {{/if}}

    {{#if @showSelectionStrip}}
      <SelectionStrip
        @engine={{@engine}}
        @focusFallback={{@focusFallback}}
        @focusStrip={{@focusStrip}}
        @hasSelectionBlock={{@hasSelectionBlock}}
        @hasUnresolvedBlock={{@hasUnresolvedBlock}}
        @locked={{@locked}}
        @onRegisterRoving={{@onRegisterStripRoving}}
        @onResize={{@onStripResize}}
        @resolveSelection={{@resolveSelection}}
        @returnToInput={{@returnToInput}}
        @value={{@value}}
      >
        <:selection as |item|>
          {{~yield item this.resolvedOptions to="selection"~}}
        </:selection>
        <:unresolved as |item|>
          {{~yield item this.resolvedOptions to="unresolved"~}}
        </:unresolved>
      </SelectionStrip>
    {{/if}}

    {{#if @hasListHeaderBlock}}
      <div class="d-select__list-header">
        {{~yield @state this.resolvedOptions to="listHeader"~}}
      </div>
    {{/if}}

    {{#if @engine.belowMinChars}}
      {{! Below the minimum query length: no source call (no request, no skeleton flash), and
        the truthy-empty-array routing and stray create-row are sidestepped by not rendering the
        list at all. Announced through the a11y service, like the limit. }}
      {{#let
        (@engine.text "minChars" (hash count=@engine.remainingMinChars))
        as |hint|
      }}
        {{#if hint}}
          <div
            class="d-select__min-chars"
            role={{@hintRole}}
            {{didInsert
              @announcer.announceMinCharsOnEntry
              @engine.remainingMinChars
            }}
            {{didUpdate
              @announcer.announceMinChars
              @engine.remainingMinChars
              @reportsActive
            }}
          >
            {{hint}}
          </div>
        {{/if}}
      {{/let}}
    {{else if @renderOptions}}
      <SelectOptions
        @announcer={{@announcer}}
        @engine={{@engine}}
        @feedback={{@feedback}}
        @filterInput={{@filterInput}}
        @hasEmptyBlock={{@hasEmptyBlock}}
        @hasErrorBlock={{@hasErrorBlock}}
        @hasSkeletonItemBlock={{@hasSkeletonItemBlock}}
        @hideEmptyQuery={{@hideEmptyQuery}}
        @listbox={{@listbox}}
        @loadListContent={{@loadListContent}}
        @multiple={{@multiple}}
        @onRegisterListbox={{@onRegisterListbox}}
        @onRegisterRoving={{@onRegisterRoving}}
        @presenter={{@presenter}}
        @reportsActive={{@reportsActive}}
        @staticBody={{@staticBody}}
      >
        <:body as |items _content modifiers|>
          <@body
            @announcer={{@announcer}}
            @engine={{@engine}}
            @hasGroupFooterBlock={{@hasGroupFooterBlock}}
            @hasGroupHeaderBlock={{@hasGroupHeaderBlock}}
            @hasItemBlock={{@hasItemBlock}}
            @hasSkeletonItemBlock={{@hasSkeletonItemBlock}}
            @hideSelectionMarker={{@hideSelectionMarker}}
            @items={{items}}
            @label={{@label}}
            @labelledBy={{@labelledBy}}
            @limitId={{if @limitMessage @limitId}}
            @listbox={{@listbox}}
            @listboxId={{@listboxId}}
            @modifiers={{modifiers}}
            @multiple={{@multiple}}
            @onOptionMousedown={{@onOptionMousedown}}
            @presenter={{@presenter}}
            @selectedIcon={{@selectedIcon}}
            @tabIndex={{@tabIndex}}
          >
            <:item as |item row|>
              {{~yield item this.resolvedOptions row to="item"~}}
            </:item>
            <:groupHeader as |item|>
              {{~yield item this.resolvedOptions to="groupHeader"~}}
            </:groupHeader>
            <:groupFooter as |item|>
              {{~yield item this.resolvedOptions to="groupFooter"~}}
            </:groupFooter>
            <:skeletonItem>
              {{~yield to="skeletonItem"~}}
            </:skeletonItem>
          </@body>
        </:body>
        <:skeletonItem>
          {{~yield to="skeletonItem"~}}
        </:skeletonItem>
        <:empty>
          {{~yield to="empty"~}}
        </:empty>
        <:error as |error retry|>
          {{~yield error retry to="error"~}}
        </:error>
      </SelectOptions>
    {{/if}}
    {{#if @hasFooterBlock}}
      {{! A labeled region pinned below the list (a sibling of the listbox, never inside it). }}
      <div
        aria-label={{@engine.text "footerLabel"}}
        class="d-select__footer"
        role="group"
      >
        {{yield @state this.resolvedOptions to="footer"}}
      </div>
    {{/if}}
  </template>
}
