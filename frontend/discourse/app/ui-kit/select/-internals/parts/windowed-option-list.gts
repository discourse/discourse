import type { TemplateOnlyComponent } from "@ember/component/template-only";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import DVirtualList from "discourse/ui-kit/d-virtual-list";
import type SelectAnnouncer from "discourse/ui-kit/select/-internals/coordinators/select-announcer";
import type { OptionsPresenter } from "discourse/ui-kit/select/-internals/coordinators/select-presenter-base";
import WindowedListCoordinator, {
  ListRow,
} from "discourse/ui-kit/select/-internals/coordinators/windowed-list-coordinator";
import SelectOptionRow from "discourse/ui-kit/select/-internals/parts/select-option-row";
import type { SelectOptionsModifiers } from "discourse/ui-kit/select/-internals/parts/select-options";
import SelectEngine, {
  SelectItem as SelectItemModel,
} from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

interface WindowedOptionListSignature {
  Args: {
    /** The headless selection engine. */
    engine: SelectEngine;
    /** The stable helper for variant-specific presentation state. */
    presenter: OptionsPresenter;
    /** The windowed-list controller. */
    listbox: WindowedListCoordinator;
    /** The stable helper for screen-reader announcements. */
    announcer: SelectAnnouncer;
    /** Explicit listbox tab index for persistent hosts. */
    tabIndex?: number;
    /** The rendered listbox id. */
    listboxId: string;
    /** Stable id of the panel's selection-limit message. */
    limitId: string;
    /** Icon marking selected rows. */
    selectedIcon?: string;
    /** Omits the selection marker, for a list that never shows a held row. */
    hideSelectionMarker?: boolean;
    /** Whether the select accepts multiple values. */
    multiple?: boolean;
    /** Accessible label for the listbox. */
    label?: string;
    /** Whether the consumer supplied custom item markup. */
    hasItemBlock: boolean;
    /** Whether the consumer supplied custom placeholder-row markup. */
    hasSkeletonItemBlock: boolean;
    /** Whether the consumer supplied custom group-header markup. */
    hasGroupHeaderBlock: boolean;
    /** Handles pointer-down on an option before its click resolves. */
    onOptionMousedown: (event: MouseEvent) => void;
    /** Composed rows for this resolved content. */
    items: readonly ListRow[];
    /** Shared modifiers from the async shell. */
    modifiers: SelectOptionsModifiers;
  };
  Blocks: {
    /** Custom markup for an item. */
    item?: [
      /** The item being rendered. */
      item: SelectItemModel,
    ];
    /** Custom markup for a group header. */
    groupHeader?: [
      /** The group-header item being rendered. */
      item: SelectItemModel,
    ];
    /** Custom markup for one placeholder row while a page of rows is loading. */
    skeletonItem?: [];
  };
}

const WindowedOptionList: TemplateOnlyComponent<WindowedOptionListSignature> =
  <template>
    <DVirtualList
      {{! A reveal or re-query keeps its rows mounted, so aria-busy reports the
          fetch itself; the frontier skeleton is the sighted counterpart. }}
      aria-busy={{if @engine.serverPending "true" "false"}}
      aria-label={{or @label (i18n "d_select.label")}}
      aria-multiselectable={{if @multiple "true"}}
      class="d-select__listbox"
      id={{@listboxId}}
      tabindex={{@tabIndex}}
      @as="ul"
      @estimateSize={{@listbox.estimateRowSize}}
      @initialAlign="center"
      {{! First render only, so it reveals the held value on open and never
            fights a reader who has scrolled. Centred rather than aligned to the top:
            a selection pinned to the first row hides the options around it, which are
            the reason the list was opened. }}
      @initialIndex={{@listbox.revealRowIndex @items}}
      @items={{@items}}
      @keepMounted={{@listbox.mountedRows @items}}
      @key="key"
      @onReachEnd={{@engine.revealMore}}
      @onRegisterApi={{@listbox.registerListboxApi}}
      @ownedRow={{true}}
      @role="listbox"
      @stickyCount={{@listbox.stickyCount @items}}
      {{! The options are reached with the arrow keys from the combobox controller, so the
            scroll viewport must not also be a tab stop: in active roving mode the rows carry no
            tabindex, which is exactly the shape a browser adopts the scroller for, and it would
            land the reader on a wrapper with nothing to do. This is also what lets the panel's
            own Tab handling enumerate its tab stops truthfully — an adopted scroller reports
            a tabIndex of -1 and matches no focusable selector, so it is invisible to any such
            enumeration while still consuming a Tab press. }}
      @viewportTabbable={{false}}
      {{! Keyed on the engine's query, not the resolved payload's. This
          modifier does no value comparison; it re-runs whenever a tag it consumed
          is dirtied, and reading the payload entangles the async resolution itself,
          which dirties on every load. Keyed that way a reveal counts as a change and
          throws the reader back to row one at the moment they scrolled for more. The
          filter and reload nonce dirty only on a real query change. }}
      {{didUpdate @listbox.resetListScroll @engine.queryKey}}
      {{@modifiers.register}}
      {{@modifiers.release}}
      {{@modifiers.recordOnEntry}}
      {{@modifiers.record}}
      {{@modifiers.countOnEntry}}
      {{@modifiers.count}}
      {{didUpdate @announcer.announceReveal @engine.serverPending}}
      {{didUpdate @listbox.rearmEndAfterPage @engine.serverPending}}
      {{! Static in the mobile modal moves DOM focus into the listbox; every other
          surface keeps focus on its controller (no-op there). }}
      {{didInsert @listbox.focusListboxIfSimple}}
      {{@modifiers.roving}}
      as |descriptor row|
    >
      {{#let (modifier row.place row.start row.index) as |place|}}
        <SelectOptionRow
          @descriptor={{descriptor}}
          @engine={{@engine}}
          @hasGroupHeaderBlock={{@hasGroupHeaderBlock}}
          @hasItemBlock={{@hasItemBlock}}
          @hasSkeletonItemBlock={{@hasSkeletonItemBlock}}
          @hideSelectionMarker={{@hideSelectionMarker}}
          @index={{row.index}}
          @items={{@items}}
          @limitId={{@limitId}}
          @listbox={{@listbox}}
          @measure={{row.measure}}
          @multiple={{@multiple}}
          @onOptionMousedown={{@onOptionMousedown}}
          @place={{place}}
          @presenter={{@presenter}}
          @selectedIcon={{@selectedIcon}}
        >
          <:item as |item|>
            {{~yield item to="item"~}}
          </:item>
          <:groupHeader as |item|>
            {{~yield item to="groupHeader"~}}
          </:groupHeader>
          <:skeletonItem>
            {{~yield to="skeletonItem"~}}
          </:skeletonItem>
        </SelectOptionRow>
      {{/let}}
    </DVirtualList>
  </template>;

export default WindowedOptionList;
