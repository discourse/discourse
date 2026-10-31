import type { TemplateOnlyComponent } from "@ember/component/template-only";
import { hash } from "@ember/helper";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { cancel, schedule } from "@ember/runloop";
import type { ModifierLike } from "@glint/template";
import { modifier as createModifier } from "ember-modifier";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DButton from "discourse/ui-kit/d-button";
import DSkeleton from "discourse/ui-kit/d-skeleton";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dRovingFocus, {
  DRovingFocusApi,
} from "discourse/ui-kit/modifiers/d-roving-focus";
import type LoadFeedbackTracker from "discourse/ui-kit/select/-internals/coordinators/load-feedback";
import type SelectAnnouncer from "discourse/ui-kit/select/-internals/coordinators/select-announcer";
import type { OptionsPresenter } from "discourse/ui-kit/select/-internals/coordinators/select-presenter-base";
import WindowedListCoordinator, {
  ListRow,
} from "discourse/ui-kit/select/-internals/coordinators/windowed-list-coordinator";
import { engineKey } from "discourse/ui-kit/select/-internals/engine/row-keys";
import SelectEngine, {
  type SelectItem as SelectItemModel,
  selectItemLabel,
  type SelectLoadOptions,
} from "discourse/ui-kit/select/select-engine";

/** Fixes the callback tuple before the template curries a lifecycle modifier. */
type ListLifecycleModifier<Args extends unknown[]> = ModifierLike<{
  Element: HTMLElement;
  Args: {
    Positional: [
      callback: (element: HTMLElement, args: Args) => unknown,
      ...args: Args,
    ];
  };
}>;

const listRelease: ListLifecycleModifier<[]> = willDestroy;
const recordOnEntry: ListLifecycleModifier<[number]> = didInsert;
const record: ListLifecycleModifier<[number]> = didUpdate;
const countOnEntry: ListLifecycleModifier<
  [number, number | undefined, string?]
> = didInsert;
const count: ListLifecycleModifier<[number, number | undefined, string?]> =
  didUpdate;

/** Registers only a rendered listbox, independently of loading and empty states. */
const registerListbox = createModifier(
  (
    element: HTMLElement,
    [register, controller]: [
      (element: HTMLElement | null) => void,
      HTMLElement | null | undefined,
    ]
  ) => {
    // Roving can seed before the deferred registration updates the input's rendered attributes.
    controller?.setAttribute("aria-controls", element.id);
    const registration = schedule("afterRender", () => register(element));
    return () => {
      if (controller?.getAttribute("aria-controls") === element.id) {
        controller.removeAttribute("aria-controls");
      }
      cancel(registration);
      schedule("afterRender", () => register(null));
    };
  }
);

/** Replaces each retained static row without changing the list's row count. */
function placeholderRows(
  items: readonly ListRow[],
  feedback: LoadFeedbackTracker,
  labelField: string,
  staticBody?: boolean
): readonly ListRow[] {
  if (!staticBody || feedback.retainRowsWhileReloading) {
    return items;
  }
  return items.length
    ? items.map((row) => ({
        key: row.key,
        isSkeleton: true,
        label: row.isSkeleton
          ? row.label
          : selectItemLabel(row.item, labelField),
      }))
    : [{ key: engineKey("skeleton:empty"), isSkeleton: true }];
}

/** Keeps popup hosts unchanged when they do not observe listbox presence. */
function ignoreListbox(): void {}

/** Per-list modifiers configured by the shared async shell. */
export interface SelectOptionsModifiers {
  /** Reports the mounted listbox and its teardown. */
  register: ModifierLike<{ Element: HTMLElement }>;
  /** Releases list state on destruction. */
  release: ModifierLike<{ Element: HTMLElement }>;
  /** Records the initial rendered row count. */
  recordOnEntry: ModifierLike<{ Element: HTMLElement }>;
  /** Records changes to the rendered row count. */
  record: ModifierLike<{ Element: HTMLElement }>;
  /** Reports the initial result count. */
  countOnEntry: ModifierLike<{ Element: HTMLElement }>;
  /** Reports changes to the result count. */
  count: ModifierLike<{ Element: HTMLElement }>;
  /** Installs the shared cursor configuration. */
  roving: ModifierLike<{ Element: HTMLElement }>;
}

export interface SelectListContent {
  /** Loader inputs for these displayed rows, retained independently of the next request. */
  context?: Readonly<Record<string, unknown>>;
  rawItems: SelectItemModel[];
  /** The filter that produced these rows, retained with them for create checks during a reload. */
  readonly filter: string;
  /**
   * The query these rows answer, captured when the load resolved. `@retainWhileReloading` keeps
   * the previous rows mounted while a new query is in flight, so `engine.queryKey` is the query
   * being *asked* while this is the query being *shown*. They differ for the whole debounce
   * plus fetch. Anything reacting to "the results changed" has to key on this one.
   */
  query: string;
}

interface SelectOptionsSignature {
  Args: {
    /** The headless selection engine. */
    engine: SelectEngine;
    /** The stable helper for variant-specific presentation state. */
    presenter: OptionsPresenter;
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
    /** Registers cursor controls with a host that owns focus independently of mounting. */
    onRegisterRoving?: (api: DRovingFocusApi | null) => void;
    /** Reports whether a listbox actually renders. */
    onRegisterListbox?: (element: HTMLElement | null) => void;
    /** Retains the static body during reloads and renders placeholders as option-shaped rows. */
    staticBody?: boolean;
    /** Suppresses an empty result state for an empty query. */
    hideEmptyQuery?: boolean;
    /** Whether visible states have live-region roles; defaults to true. */
    reportsActive?: boolean;
    /** Whether the select accepts multiple values. */
    multiple?: boolean;
    /** Whether the consumer supplied custom placeholder-row markup. */
    hasSkeletonItemBlock: boolean;
    /** Whether the consumer supplied custom empty-state markup. */
    hasEmptyBlock: boolean;
    /** Whether the consumer supplied custom error-state markup. */
    hasErrorBlock: boolean;
  };
  Blocks: {
    /** Renders the resolved nonempty option list. */
    body: [
      /** Composed rows, including structural and frontier rows. */
      items: readonly ListRow[],
      /** Snapshot of the resolved source query. */
      content: SelectListContent | undefined,
      /** Configured per-list behavior, applied in body order. */
      modifiers: SelectOptionsModifiers,
    ];
    /** Custom markup for one placeholder row while a page of rows is loading. */
    skeletonItem?: [];
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

interface LoadingListSignature {
  Args: {
    engine: SelectEngine;
    feedback: LoadFeedbackTracker;
    staticBody?: boolean;
    hasSkeletonItemBlock: boolean;
  };
  Blocks: { skeletonItem: [] };
}

/** The list while rows are loading, or while a paste resolves. */
const LoadingList: TemplateOnlyComponent<LoadingListSignature> = <template>
  {{! The skeleton scrolls itself, and its rows are inert placeholders, so it would be
  adopted as a tab stop by a browser with keyboard-focusable scrollers — a stop onto
  nothing, in a panel the reader is still waiting on. }}
  <ul
    aria-busy="true"
    class="d-select__listbox
      {{if @staticBody 'd-select__options' 'd-select__listbox--loading'}}"
    tabindex="-1"
  >
    {{#if (or (not @staticBody) @feedback.showInitialPlaceholder)}}
      {{#if @engine.resolvedOptions.loadingStatus}}
        <li class="d-select__loading-status" role="status">
          {{dIcon "spinner" class="d-select__pending-icon"}}
          <span>
            {{~@engine.text "loadingLabel"~}}
          </span>
        </li>
      {{/if}}
      {{#each @feedback.skeletonRows key="key" as |row|}}
        <li
          aria-hidden={{if @staticBody "true"}}
          class={{if
            @staticBody
            "d-select__option --placeholder"
            "d-select__skeleton"
          }}
          data-key={{row.key}}
        >
          {{#if @staticBody}}
            {{! An empty label gives the placeholder a row's line height and a varied width. }}
            <span class="d-select__placeholder-label"></span>
          {{/if}}
          {{#if @hasSkeletonItemBlock}}
            {{yield to="skeletonItem"}}
          {{else}}
            <DSkeleton @variant="text" />
          {{/if}}
        </li>
      {{/each}}
    {{/if}}
  </ul>
</template>;

const SelectOptions: TemplateOnlyComponent<SelectOptionsSignature> = <template>
  {{#if @engine.pastePending}}
    <LoadingList
      @engine={{@engine}}
      @feedback={{@feedback}}
      @hasSkeletonItemBlock={{@hasSkeletonItemBlock}}
      @staticBody={{@staticBody}}
    >
      <:skeletonItem>
        {{yield to="skeletonItem"}}
      </:skeletonItem>
    </LoadingList>
  {{else}}
    <DAsyncContent
      @asyncData={{@loadListContent}}
      @context={{@engine.loadContext}}
      @debounce={{@presenter.debounceFor}}
      @retainWhileReloading={{or
        @staticBody
        @feedback.retainRowsWhileReloading
      }}
    >
      <:loading>
        <LoadingList
          @engine={{@engine}}
          @feedback={{@feedback}}
          @hasSkeletonItemBlock={{@hasSkeletonItemBlock}}
          @staticBody={{@staticBody}}
        >
          <:skeletonItem>
            {{yield to="skeletonItem"}}
          </:skeletonItem>
        </LoadingList>
      </:loading>

      <:content as |content|>
        {{#let
          (placeholderRows
            (@listbox.buildListItems content.rawItems content.filter)
            @feedback
            @presenter.labelField
            @staticBody
          )
          as |items|
        }}
          {{#if items.length}}
            {{! The resolved query is a key as much as an argument: a query that lands
          on the rows it already had changes neither count, so without it this never
          re-runs and a reader typing on hears nothing at all. }}
            {{! The controller (query input, or the desktop-static trigger div) keeps
          focus and drives the highlight via aria-activedescendant. Static in the
          mobile modal roves the tabindex through the options instead, since its
          out-of-modal trigger cannot be the controller. Where the cursor lands on
          open is the presenter's entry convention; re-seed when async lands. }}
            {{#let
              (modifier
                registerListbox
                (or @onRegisterListbox ignoreListbox)
                (if @presenter.usesActiveRoving @filterInput)
              )
              (modifier listRelease @listbox.releaseListbox)
              (modifier recordOnEntry @feedback.recordRowCount items.length)
              (modifier record @feedback.recordRowCount items.length)
              (modifier
                countOnEntry
                @announcer.announceCountOnEntry
                (@listbox.setSizeOf items)
                @engine.total
                content.query
              )
              (modifier
                count
                @announcer.announceCount
                (@listbox.setSizeOf items)
                @engine.total
                content.query
              )
              (modifier
                dRovingFocus
                focusStrategy=(if
                  @presenter.usesActiveRoving
                  "active-descendant"
                  "roving-tabindex"
                )
                controllerElement=(if @presenter.usesActiveRoving @filterInput)
                disabledItems="focusable"
                itemSelector="[role=option]"
                itemsKey=(@presenter.rovingItemsKey items)
                resetKey=content.query
                logicalCount=(@listbox.navigableCount items)
                onActivate=@listbox.activateElement
                onActiveChange=@listbox.trackActiveOption
                onJump=@listbox.handleJump
                onRegisterApi=(or
                  @onRegisterRoving @listbox.registerListboxRoving
                )
                entryFocus=@presenter.entryFocus
                fallbackSkipsMarked=@multiple
              )
              as |register release recordEntry recordUpdate countEntry countUpdate roving|
            }}
              {{yield
                items
                content
                (hash
                  register=register
                  release=release
                  recordOnEntry=recordEntry
                  record=recordUpdate
                  countOnEntry=countEntry
                  count=countUpdate
                  roving=roving
                )
                to="body"
              }}
            {{/let}}

            {{#if @engine.atCapWithMore}}
              {{#let (@engine.text "maxLoaded") as |narrow|}}
                {{#if narrow}}
                  {{! Sits outside the listbox, which admits only list items. The text also
              goes through the a11y service because a live region announces unreliably on
              the render that mounts it. }}
                  <div
                    class="d-select__narrow"
                    role={{unless (eq @reportsActive false) "status"}}
                    {{didInsert @announcer.announceNarrow}}
                  >
                    {{narrow}}
                  </div>
                {{/if}}
              {{/let}}
            {{/if}}
          {{else if (or content.filter (not @hideEmptyQuery))}}
            {{! Recorded here too, not only on the list: a query that found nothing is a
            rendered state with a row count of zero, and leaving the previous count
            standing would size the next reload's skeleton to a list that is gone. }}
            {{! The update hook is load-bearing, not belt-and-braces. The async content
            wrapper reports the same render mode for both the resolved and the
            retained-pending phase, so Glimmer keeps this node mounted across two
            successive empty queries — an insert-only announcement would report the
            first and then stay silent for the rest of the session.

            Keyed on the resolved query, never the engine query, which advances on
            a keystroke or reload. That would report an empty result for a query still in
            flight, over rows that still belong to the previous one. }}
            {{! An empty text keeps the element, without a role, because it still
            records the row count and replaces a held result count. }}
            {{#let (@engine.text "noResults") as |noResults|}}
              <div
                class="d-select__empty"
                role={{if
                  (and
                    (not (eq @reportsActive false))
                    (or @hasEmptyBlock noResults)
                  )
                  "status"
                }}
                {{didInsert @feedback.recordRowCount 0}}
                {{didInsert @announcer.announceNoResults content.query}}
                {{didUpdate @announcer.announceNoResults content.query}}
              >
                {{#if @hasEmptyBlock}}
                  {{yield to="empty"}}
                {{else}}
                  {{noResults}}
                {{/if}}
              </div>
            {{/let}}
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
        <div
          class="d-select__error"
          role={{unless (eq @reportsActive false) "alert"}}
        >
          {{#if @hasErrorBlock}}
            {{yield error @engine.reload to="error"}}
          {{else}}
            <span class="d-select__error-message">
              {{dIcon "triangle-exclamation"}}
              {{@engine.text "loadError"}}
            </span>
            {{#if @presenter.retryable}}
              <DButton
                class="d-select__retry btn-flat"
                @action={{@engine.reload}}
                @translatedLabel={{@engine.text "retry"}}
              />
            {{/if}}
          {{/if}}
        </div>
      </:error>
    </DAsyncContent>
  {{/if}}
</template>;

export default SelectOptions;
