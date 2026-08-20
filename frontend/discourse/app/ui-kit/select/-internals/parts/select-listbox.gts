import type { TemplateOnlyComponent } from "@ember/component/template-only";
import { on } from "@ember/modifier";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import booleanString from "discourse/helpers/boolean-string";
import { eq, or } from "discourse/truth-helpers";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DButton from "discourse/ui-kit/d-button";
import DSkeleton from "discourse/ui-kit/d-skeleton";
import DVirtualList from "discourse/ui-kit/d-virtual-list";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dRovingFocus from "discourse/ui-kit/modifiers/d-roving-focus";
import type LoadFeedbackTracker from "discourse/ui-kit/select/-internals/coordinators/load-feedback";
import type SelectAnnouncer from "discourse/ui-kit/select/-internals/coordinators/select-announcer";
import type VariantPresenter from "discourse/ui-kit/select/-internals/coordinators/variant-presenter";
import type WindowedListCoordinator from "discourse/ui-kit/select/-internals/coordinators/windowed-list-coordinator";
import SelectItem from "discourse/ui-kit/select/-internals/parts/select-item";
import SelectEngine, {
  type SelectItem as SelectItemModel,
  selectItemLabel,
  type SelectLoadOptions,
} from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

export interface SelectListContent {
  rawItems: SelectItemModel[];
  /**
   * The query these rows answer, captured when the load resolved. `@retainWhileReloading` keeps
   * the previous rows mounted while a new query is in flight, so `engine.filter` is the query
   * being *asked* while this is the query being *shown* — they differ for the whole debounce
   * plus fetch. Anything reacting to "the results changed" has to key on this one.
   */
  filter: string;
}

interface SelectListboxSignature {
  Args: {
    /** The headless selection engine. */
    engine: SelectEngine;
    /** The stable helper for variant-specific presentation state. */
    presenter: VariantPresenter;
    /** The stable helper for loading feedback state. */
    feedback: LoadFeedbackTracker;
    /** The windowed-list controller. */
    listbox: WindowedListCoordinator;
    /** The stable helper for screen-reader announcements. */
    announcer: SelectAnnouncer;
    /** Loads the list content for the current async context. */
    loadListContent: (
      context: unknown,
      options?: SelectLoadOptions
    ) => SelectListContent | Promise<SelectListContent>;
    /** The element controlling active-descendant roving focus. */
    filterInput: HTMLElement | null;
    /** The rendered listbox id. */
    listboxId: string;
    /** Icon marking selected rows. */
    selectedIcon?: string;
    /** Whether the select accepts multiple values. */
    multiple?: boolean;
    /** Accessible label for the listbox. */
    label?: string;
    /** Consumer-provided label for an empty result set. */
    noResultsLabel?: string;
    /** Whether the consumer supplied custom item markup. */
    hasItemBlock: boolean;
    /** Whether the consumer supplied custom group-header markup. */
    hasGroupHeaderBlock: boolean;
    /** Whether the consumer supplied custom empty-state markup. */
    hasEmptyBlock: boolean;
    /** Whether the consumer supplied custom error-state markup. */
    hasErrorBlock: boolean;
    /** Handles pointer-down on an option before its click resolves. */
    onOptionMousedown: (event: MouseEvent) => void;
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
    /** Custom markup for the empty state. */
    empty?: [];
    /** Custom markup for the error state. */
    error?: [
      /** The rejection reason. */
      error: Error,
      /** Reloads the list source. */
      retry: () => void,
    ];
  };
}

const SelectListbox: TemplateOnlyComponent<SelectListboxSignature> = <template>
  <DAsyncContent
    @asyncData={{@loadListContent}}
    @context={{@engine.loadContext}}
    @debounce={{@presenter.debounce}}
    @retainWhileReloading={{@feedback.retainRowsWhileReloading}}
  >
    <:loading>
      {{! The skeleton scrolls itself, and its rows are inert placeholders, so it would be
      adopted as a tab stop by a browser with keyboard-focusable scrollers — a stop onto
      nothing, in a panel the reader is still waiting on. }}
      <ul
        class="d-combobox__listbox d-combobox__listbox--loading"
        aria-busy="true"
        tabindex="-1"
      >
        {{#each @feedback.skeletonRows key="key" as |row|}}
          <li class="d-combobox__skeleton" data-key={{row.key}}>
            <DSkeleton @variant="text" />
          </li>
        {{/each}}
      </ul>
    </:loading>

    <:content as |content|>
      {{#let (@listbox.buildListItems content.rawItems) as |items|}}
        {{#if items.length}}
          <DVirtualList
            @as="ul"
            @role="listbox"
            @ownedRow={{true}}
            @key="key"
            @items={{items}}
            @estimateSize={{@listbox.estimateRowSize}}
            @onReachEnd={{@engine.revealMore}}
            @onRegisterApi={{@listbox.registerListboxApi}}
            @pinnedIndices={{@listbox.windowPins items}}
            {{! The options are reached with the arrow keys from the combobox controller, so the
            scroll viewport must not also be a tab stop: in active roving mode the rows carry no
            tabindex, which is exactly the shape a browser adopts the scroller for, and it would
            land the reader on a wrapper with nothing to do. This is also what lets the panel's
            own Tab handling enumerate its tab stops truthfully — an adopted scroller reports
            a tabIndex of -1 and matches no focusable selector, so it is invisible to any such
            enumeration while still consuming a Tab press. }}
            @viewportTabbable={{false}}
            {{! First render only, so it reveals the held value on open and never
            fights a reader who has scrolled. Centred rather than aligned to the top:
            a selection pinned to the first row hides the options around it, which are
            the reason the list was opened. }}
            @initialIndex={{@listbox.revealRowIndex items}}
            @initialAlign="center"
            class="d-combobox__listbox"
            id={{@listboxId}}
            aria-label={{or @label (i18n "d_select.label")}}
            aria-multiselectable={{booleanString @multiple}}
            {{! A reveal or re-query keeps its rows mounted, so aria-busy reports the
          fetch itself; the frontier skeleton is the sighted counterpart. }}
            aria-busy={{booleanString @engine.serverPending omitFalse=false}}
            {{! Keyed on the engine's filter, NOT the resolved payload's. This
          modifier does no value comparison; it re-runs whenever a tag it consumed
          is dirtied, and reading the payload entangles the async resolution itself,
          which dirties on every load. Keyed that way a reveal counts as a change and
          throws the reader back to row one at the moment they scrolled for more. The
          filter's own tag dirties only on a real query change. }}
            {{didUpdate @listbox.resetListScroll @engine.filter}}
            {{willDestroy @listbox.releaseListbox}}
            {{didInsert @feedback.recordRowCount items.length}}
            {{didUpdate @feedback.recordRowCount items.length}}
            {{didInsert
              @announcer.announceCountOnEntry
              items.length
              @engine.total
              content.filter
            }}
            {{! The resolved filter is a key as much as an argument: a query that lands
          on the rows it already had changes neither count, so without it this never
          re-runs and a reader typing on hears nothing at all. }}
            {{didUpdate
              @announcer.announceCount
              items.length
              @engine.total
              content.filter
            }}
            {{didUpdate @announcer.announceReveal @engine.serverPending}}
            {{! Static in the mobile modal moves DOM focus into the listbox; every other
          surface keeps focus on its controller (no-op there). }}
            {{didInsert @listbox.focusListboxIfSimple}}
            {{! The controller (query input, or the desktop-static trigger div) keeps
          focus and drives the highlight via aria-activedescendant. Static in the
          mobile modal roves the tabindex through the options instead, since its
          out-of-modal trigger cannot be the controller. Where the cursor lands on
          open is the presenter's entry convention; re-seed when async lands. }}
            {{dRovingFocus
              focusStrategy=(if
                @presenter.usesActiveRoving
                "active-descendant"
                "roving-tabindex"
              )
              controllerElement=(if @presenter.usesActiveRoving @filterInput)
              itemSelector="[role=option]"
              itemsKey=(if
                @presenter.isTypeahead items @presenter.rovingNonTypeaheadKey
              )
              resetKey=content.filter
              logicalCount=(@listbox.navigableCount items)
              onActivate=@listbox.activateElement
              onActiveChange=@listbox.trackActiveOption
              onJump=@listbox.handleJump
              onRegisterApi=@listbox.registerListboxRoving
              entryFocus=@presenter.entryFocus
              fallbackSkipsMarked=@multiple
            }}
            as |descriptor row|
          >
            {{! A windowed list can yield a row whose backing item briefly does not
            exist: when the items array shrinks, the virtualizer's last published
            window still references the old indices until it re-flushes. Render
            nothing for that transient slot rather than dereferencing an absent
            descriptor. }}
            {{#if descriptor}}
              {{#let (@listbox.optionRow descriptor) as |option|}}
                {{#if option.flags.group}}
                  {{! A group header: presentational, so it is skipped by roving
                  navigation and carries no option position. }}
                  <li
                    class="d-combobox__group-header"
                    role="presentation"
                    data-option-key={{option.key}}
                    {{row.place row.start row.index}}
                    {{row.measure}}
                  >
                    {{#if @hasGroupHeaderBlock}}
                      {{yield option.item to="groupHeader"}}
                    {{/if}}
                    <span
                      id={{option.headerId}}
                      hidden={{@hasGroupHeaderBlock}}
                    >
                      {{selectItemLabel option.item "label"}}
                    </span>
                  </li>
                {{else if option.flags.divider}}
                  <li
                    class="d-combobox__divider"
                    role="presentation"
                    aria-hidden="true"
                    {{row.place row.start row.index}}
                    {{row.measure}}
                  ></li>
                {{else if option}}
                  <SelectItem
                    @descriptor={{option}}
                    @engine={{@engine}}
                    @multiple={{@multiple}}
                    @selectedIcon={{@selectedIcon}}
                    @locked={{@presenter.isLocked}}
                    @active={{eq option.key @listbox.activeOptionKey}}
                    aria-posinset={{option.posInSet}}
                    aria-setsize={{option.setSize}}
                    aria-describedby={{option.groupHeaderId}}
                    data-option-key={{option.key}}
                    data-logical-index={{option.logicalIndex}}
                    {{row.place row.start row.index}}
                    {{row.measure}}
                    {{! Keep focus in the trigger input on pointer-select so the input
                does not blur-close the menu before the click resolves (needed for
                action rows, which keep the menu open). mousedown is required:
                blur fires before click; the handler no-ops for non-typeahead. }}
                    {{! eslint-disable-next-line ember/template-no-pointer-down-event-binding }}
                    {{on "mousedown" @onOptionMousedown}}
                  >
                    {{#if @hasItemBlock}}
                      {{yield option.item to="item"}}
                    {{else}}
                      {{selectItemLabel option.item @presenter.labelField}}
                    {{/if}}
                  </SelectItem>
                {{else}}
                  {{! Frontier placeholder for an in-flight reveal: presentation, no
              posinset, so pending rows never enter the option set. }}
                  <li
                    class="d-combobox__skeleton"
                    role="presentation"
                    aria-hidden="true"
                    {{row.place row.start row.index}}
                    {{row.measure}}
                  >
                    <DSkeleton @variant="text" />
                  </li>
                {{/if}}
              {{/let}}
            {{/if}}
          </DVirtualList>

          {{#if @engine.atCapWithMore}}
            {{! Sits outside the listbox, which admits only list items. The text also
          goes through the a11y service because a live region announces unreliably on
          the render that mounts it. }}
            <div
              class="d-combobox__narrow"
              role="status"
              {{didInsert @announcer.announceNarrow}}
            >
              {{i18n "d_select.filter_to_narrow"}}
            </div>
          {{/if}}
        {{else}}
          {{! Recorded here too, not only on the list: a query that found nothing is a
            rendered state with a row count of zero, and leaving the previous count
            standing would size the next reload's skeleton to a list that is gone. }}
          {{! The update hook is load-bearing, not belt-and-braces. The async content
            wrapper reports the same render mode for both the resolved and the
            retained-pending phase, so Glimmer keeps this node mounted across two
            successive empty queries — an insert-only announcement would report the
            first and then stay silent for the rest of the session.

            Keyed on the resolved filter, never the engine filter, which advances on
            the keystroke. That would report an empty result for a query still in
            flight, over rows that still belong to the previous one. }}
          <div
            class="d-combobox__empty"
            role="status"
            {{didInsert @feedback.recordRowCount 0}}
            {{didInsert @announcer.announceNoResults content.filter}}
            {{didUpdate @announcer.announceNoResults content.filter}}
          >
            {{#if @hasEmptyBlock}}
              {{yield to="empty"}}
            {{else}}
              {{or @noResultsLabel (i18n "d_select.no_results")}}
            {{/if}}
          </div>
        {{/if}}
      {{/let}}
    </:content>

    <:error as |error|>
      {{! A muted, recoverable state matching the empty/min-chars language — not a
        heavy alert box, but still role=alert so the failure is announced (an inserted
        role=status is not reliably spoken).

        The container is the component's, exactly as the empty state's is: a block
        supplies the contents, never the wrapper. Letting a block replace the wrapper
        would silently drop the alert role and the retry control, leaving the failure
        unannounced and unrecoverable. The reload action is still yielded, so a block
        that wants its own retry control can have one. }}
      <div class="d-combobox__error" role="alert">
        {{#if @hasErrorBlock}}
          {{yield error @engine.reload to="error"}}
        {{else}}
          <span class="d-combobox__error-message">
            {{dIcon "triangle-exclamation"}}
            {{i18n "d_select.load_error"}}
          </span>
          {{#if @presenter.retryable}}
            <DButton
              class="d-combobox__retry btn-flat"
              @action={{@engine.reload}}
              @label="d_select.retry"
            />
          {{/if}}
        {{/if}}
      </div>
    </:error>
  </DAsyncContent>
</template>;

export default SelectListbox;
