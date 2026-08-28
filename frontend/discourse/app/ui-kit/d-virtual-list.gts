import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import type { ModifierLike } from "@glint/template";
import { modifier } from "ember-modifier";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dElement from "discourse/ui-kit/helpers/d-element";
import {
  isVirtualizationEnabled,
  keyFor,
} from "discourse/ui-kit/lib/virtualizer";
import dVirtualizer from "discourse/ui-kit/modifiers/d-virtualizer";

/** A single measured/positioned row as published by the engine. */
interface VirtualItem {
  key: number | string | bigint;
  index: number;
  start: number;
  size: number;
}

/**
 * The positioning modifier, applied as `{{row.place row.start row.index}}`. Its
 * positional args carry the row's offset and absolute index.
 *
 * One stable definition shared by every row, so a row that survives a re-render
 * re-runs its existing instance instead of being destroyed and reinstalled —
 * where the destroy could run after the replacement wrote its styles and strip
 * them off the reused element.
 */
type PlaceModifier = ModifierLike<{
  Element: HTMLElement;
  Args: { Positional: [start: number, index: number] };
}>;

/**
 * The per-row context yielded as the block's second parameter. In `@ownedRow`
 * mode the consumer renders the row element itself and applies `{{row.place}}`
 * (positioning) and `{{row.measure}}` (measurement); simple consumers can ignore
 * it and let the primitive wrap their content.
 */
interface RowContext<T> {
  item: T;
  index: number;
  key: number | string | bigint;
  start: number;
  size: number;
  /**
   * Positions the row (absolute + `translateY`) when windowing; inert in the
   * render-all fallback. Apply with the row's offset and index:
   * `{{row.place row.start row.index}}`.
   *
   * Apply it BEFORE {@link measure}. It stamps the `data-index` that measurement
   * identifies the row by, and modifiers run in template order.
   */
  place: PlaceModifier;
  /**
   * Registers the row for height measurement. Arg-less and stable; apply once per row,
   * AFTER {@link place} — a row reached before its `data-index` is stamped cannot be
   * identified, so it is skipped and keeps rendering at `@estimateSize`.
   */
  measure: ModifierLike<HTMLElement>;
  /**
   * The row's `aria-posinset`, or undefined when `@itemRole` is not a role that
   * defines it. Meaningful only when every entry in `@items` is a real row: a
   * list that also carries headers, dividers, or placeholders has to derive its
   * own logical positions, because this counts physical rows.
   */
  posinset: number | undefined;
  /** The matching `aria-setsize`. Carries the same homogeneity caveat as {@link posinset}. */
  setSize: number | undefined;
}

/** The imperative handle registered via `@onRegisterApi`. */
export interface DVirtualListApi {
  /**
   * Scroll a row into view.
   *
   * @param index - Absolute index in `@items`.
   * @param opts - Placement within the viewport, and how to animate getting there.
   */
  scrollToIndex(
    index: number,
    opts?: {
      align?: "start" | "center" | "end" | "auto";
      behavior?: ScrollBehavior;
    }
  ): void;

  /**
   * Scroll to an absolute pixel offset in the list's coordinate space.
   *
   * @param offset - Offset in px from the start of the list.
   * @param opts - How to animate getting there.
   */
  scrollToOffset(offset: number, opts?: { behavior?: ScrollBehavior }): void;

  /**
   * Scroll to the first or last row. A no-op on an empty list.
   *
   * @param edge - Which end to travel to.
   */
  scrollToEdge(edge: "start" | "end"): void;

  /**
   * Let an edge callback fire again.
   *
   * An edge callback fires once and then latches, and re-arms on its own only when the reader
   * retreats from the band or a boundary row changes. A consumer whose fetch FAILED has
   * neither: the item set is byte-for-byte what it was, so nothing re-arms and the callback
   * never fires again. On a list short enough that the range never leaves the band, that is
   * permanent. This is the lever for that case.
   *
   * Arming is not firing. The callback runs on the next evaluation, and only if the range is
   * still inside the band.
   *
   * @param edge - Which edge to re-arm. The other is left alone.
   */
  armEdge(edge: "start" | "end"): void;

  /**
   * Discard every cached row measurement so the next window re-measures from
   * `@estimateSize`. Leaves the viewport measurement untouched.
   */
  measure(): void;

  /**
   * Re-reads the viewport's size and republishes the window from it.
   *
   * For a consumer that changes the viewport's size itself and would otherwise wait on a
   * resize being observed, which the browser schedules and may not deliver promptly. Distinct
   * from `measure`, which clears the item-size cache and leaves the viewport untouched.
   */
  remeasureViewport(): void;
  /**
   * Registers one row element for height measurement.
   *
   * Internal plumbing for the row `measure` modifier, exposed because that modifier is
   * yielded to consumers. The element must carry the `data-index` that `place` stamps;
   * anything else is ignored rather than measured under a key that does not exist.
   */
  measureElement(element: HTMLElement): void;

  /**
   * The visible index range, or undefined before the first measurement.
   *
   * A frozen snapshot, never the engine's own range object: the committed value of that
   * object is what the engine's change memo compares against, so a consumer writing
   * through it could silently stop the window updating. Every call builds a new
   * object, so compare the indices rather than the identity.
   */
  visibleRange():
    | Readonly<{ startIndex: number; endIndex: number }>
    | undefined;

  /** Whether the viewport is mid-scroll. */
  readonly isScrolling: boolean;
}

interface VisibleRange {
  startIndex: number;
  endIndex: number;
}

interface VirtualRange extends VisibleRange {
  overscan: number;
  count: number;
}

/** The visible range plus the total item count, passed to an edge callback. */
interface EdgeInfo extends VisibleRange {
  count: number;
}

/**
 * Roles for which `aria-setsize`/`aria-posinset` are defined. On anything else
 * assistive tech discards them.
 */
const POSITION_AWARE_ROLES = new Set([
  "article",
  "listitem",
  "menuitem",
  "menuitemcheckbox",
  "menuitemradio",
  "option",
  "radio",
  "row",
  "tab",
  "treeitem",
]);

interface DVirtualListSignature<T> {
  Args: {
    /**
     * The full backing array. Only a window is rendered; it is never sliced.
     *
     * The sizer is one element as tall as the whole list, so browsers cap the
     * reachable range at their maximum element height (on the order of 33 million
     * px). Beyond `ceiling / @estimateSize` rows the tail cannot be scrolled to,
     * and `@initialIndex` past it lands short.
     */
    items: readonly T[];
    /** Estimated px size for a not-yet-measured row. A good estimate reduces jump. */
    estimateSize: (item: T, index: number) => number;
    /**
     * Field name whose value is a row's STABLE key. Omit it and rows key by object
     * identity — fine when `@items` holds the same objects across renders, but a
     * consumer that rebuilds its item objects each render (same logical rows, fresh
     * objects) would orphan every measured height and remount the whole window.
     * Point `@key` at a stable id/key field to tie a row to its logical identity.
     * The field must be present and unique per logical row (a missing/duplicate
     * value aliases two rows to one key); nullish/primitive rows fall back to
     * identity keying.
     */
    key?: string;
    /** Extra rows rendered above/below the viewport to cut mount churn (default 5). */
    overscan?: number;
    /**
     * Tag name for the inner container that carries `@role`, `...attributes`, and
     * the rows (the semantic element — e.g. `"ul"` for a listbox). Resolved once
     * at mount, with an omitted or empty value falling back to `"div"`.
     *
     * A container with a content model, such as `ul` or `ol`, requires
     * `@ownedRow`: the wrapped path emits `div` rows, which those elements do not
     * permit as children.
     *
     * A list container keeps its native markers unless it also carries a `@role`,
     * since suppressing them costs the implicit list semantics some screen readers
     * derive from the marker. The container's own box spacing is zeroed either
     * way, so a consumer that wants visible markers owns both `list-style` and the
     * indent they need.
     */
    as?: string;
    /** Gives consumers a stable hook for sizing and styling the scroll viewport. */
    viewportClass?: string;
    /**
     * Names a scroll region whose non-interactive role offers no other naming path.
     * Naming it also makes it a `region`, since a role-less element cannot be named.
     */
    viewportLabel?: string;
    /** Names the scroll viewport from existing descriptive content, as `@viewportLabel` does. */
    viewportLabelledBy?: string;
    /**
     * Whether the scroll viewport may take sequential focus. Defaults to `true`, which leaves
     * the decision to the browser.
     *
     * A browser with keyboard-focusable scrollers adopts a scroll container as a tab stop when
     * it holds no focusable descendants, so that a list which can only be read by scrolling is
     * still reachable from the keyboard. Pass `false` when the rows are already reachable some
     * other way and that tab stop would be a dead end — a listbox whose cursor is driven by
     * `aria-activedescendant`, for instance, leaves its options without a tabindex but is fully
     * navigable with the arrow keys from its controller.
     *
     * Opt out only with such a route in hand: without one this removes the sole keyboard access
     * to the list's content.
     */
    viewportTabbable?: boolean;
    /**
     * When set, the default block yields `[item, rowContext]` and the CONSUMER
     * renders the row element, applying `{{rowContext.place}}` + `{{rowContext.measure}}`
     * (no wrapper, native semantic rows). When omitted, the primitive wraps the
     * yielded content in its own measured, `@itemRole`-stamped row element.
     */
    ownedRow?: boolean;
    /**
     * `"bottom"` rests at the end on mount and then follows appended rows, so a
     * live-updating list stays on its newest content. Following is bounded by
     * `@scrollEndThreshold`: a reader who has scrolled away from the end keeps
     * their position and is never pulled down by arriving rows. Default `"top"`.
     */
    anchor?: "top" | "bottom";
    /**
     * Distance from the end, in px, that still counts as resting at the end.
     * Governs whether `@anchor="bottom"` follows an append, and whether a row
     * resize preserves the at-end position.
     *
     * Defaults to the engine's own 1px, which means "exactly at the end". A
     * bottom-anchored list almost always wants this higher, so that a reader
     * sitting a few px short of the end still counts as following.
     */
    scrollEndThreshold?: number;
    /**
     * On the FIRST render only, scroll so this absolute index is revealed (per
     * `@initialAlign`). Applied once at mount; a later `@items` change never
     * re-scrolls, so it cannot fight the user. Takes precedence over
     * `@anchor="bottom"`.
     *
     * The scroll is applied a tick after the first render, because the sizer must
     * take its height before the viewport can scroll past its initially-empty
     * content. A deep index is therefore reached on the frame after the first
     * paint rather than before it.
     */
    initialIndex?: number;
    /** Alignment for `@initialIndex` within the viewport. Default `"start"`. */
    initialAlign?: "start" | "center" | "end" | "auto";
    /**
     * Extends the default window with extra absolute indices to keep mounted.
     *
     * REACTIVITY CONTRACT: pass a NEW function whenever any closed-over input
     * changes (normally by invoking a template helper). Function identity is what
     * re-triggers the modifier and updates the engine options.
     *
     * PURITY CONTRACT: the engine invokes this during its own flush, outside any
     * tracking frame, and memoizes by extractor identity plus range. Tracked state
     * read inside the callback is silently non-reactive; it must be pure over its
     * arguments and a closed-over snapshot. A callback that throws degrades to the
     * unextended window and is not consulted again until its identity or the range
     * changes.
     *
     * This is also the mechanism for keeping a row mounted that must not be
     * destroyed while scrolled out of the window. A consumer managing focus or a
     * roving tabindex has to pin the active index, or scrolling past it unmounts
     * the focused element and focus falls back to the document.
     */
    pinnedIndices?: (
      indices: readonly number[],
      range: VirtualRange
    ) => readonly number[];
    /**
     * Role for the inner container (the semantic element), e.g. `"listbox"` or
     * `"feed"`. Omitted by default: a role is a promise about keyboard behaviour
     * the primitive does not implement on the consumer's behalf, so the consumer
     * opts in.
     *
     * With a non-interactive role, nothing inside the list is focusable. Use
     * `@viewportClass` as the hook for making the viewport focusable, and name
     * it with `@viewportLabel` or `@viewportLabelledBy`, so the region can be
     * scrolled without a pointer.
     */
    role?: string;
    /**
     * The role each row carries, e.g. `"listitem"` or `"option"`.
     *
     * Without `@ownedRow` it is stamped on the row the primitive renders. With
     * `@ownedRow` the consumer stamps the role itself and this only declares what
     * that role will be, which is what lets `row.posinset` and `row.setSize` be
     * computed — they are defined for a handful of roles and are omitted for the
     * rest, so the primitive has to be told.
     *
     * The wrapped row exposes no `id` and no attribute pass-through, so a role
     * needing `aria-selected`, `aria-checked`, or an id to be pointed at by
     * `aria-activedescendant` — `option`, `radio`, `tab`, `treeitem` — cannot be
     * fully expressed there and needs `@ownedRow`.
     */
    itemRole?: string;
    /**
     * Overrides `aria-setsize`. Only needed when `@items` is itself a window
     * over an unbounded stream, where the true total is unknowable: pass `-1`.
     */
    setSize?: number;
    /** Receives the imperative handle once mounted. */
    onRegisterApi?: (api: DVirtualListApi) => void;
    /** Fires when the visible index range changes. */
    onVisibleRangeChange?: (range: VisibleRange) => void;
    /**
     * Fires once when the window enters the START band (within `@edgeThreshold`
     * rows of the first row), re-arming after it retreats. Mount at the top is
     * suppressed. A start-edge consumer loads rows ABOVE the anchor.
     */
    onReachStart?: (info: EdgeInfo) => void;
    /**
     * Fires once when the window enters the END band (within `@edgeThreshold`
     * rows of the last row), re-arming after retreat. Fires on mount when the
     * first page already reaches the end. An end-edge consumer loads more rows.
     */
    onReachEnd?: (info: EdgeInfo) => void;
    /** Rows from an edge at which its reach callback arms (default 8). */
    edgeThreshold?: number;
  };
  Blocks: {
    /** Renders each item in the active window. */
    default: [
      /** The backing-array item. */
      item: T,
      /** Its measured position and row modifiers. */
      row: RowContext<T>,
    ];
    /** Renders when the backing array is empty. */
    empty: [];
  };
  Element: HTMLElement;
}

/**
 * Renders only a window of a large list while keeping the DOM bounded. The
 * windowing engine remains behind the ui-kit library boundary.
 *
 * Structure: an outer role-less `.d-virtual-list` scroll VIEWPORT (the element the
 * `dVirtualizer` modifier drives) wraps an inner `@as` CONTAINER — the semantic
 * element that carries `@role`/`...attributes` and is the sizer (`height` = the
 * full total) — whose rows are direct children, each absolutely positioned to its
 * virtual offset. The component owns the tracked window (`_virtualItems`); the
 * modifier owns the engine and pushes state in through `onState`.
 *
 * The consumer must give the outer viewport a nonzero height. Without one,
 * windowing has no visible area and renders no rows.
 *
 * Simple consumers yield content and let the primitive wrap it in a measured,
 * `@itemRole`-stamped row. A consumer that needs native row elements passes
 * `@ownedRow` and renders the element itself, applying both
 * `{{row.place row.start row.index}}` (positioning; also stamps `data-index`) and
 * `{{row.measure}}` (height measurement). Neither requires the consumer to set
 * `data-index`.
 *
 * @example
 * ```gjs
 * <DVirtualList @items={{this.rows}} @estimateSize={{this.estimate}} as |row|>
 *   <MyRow @row={{row}} />
 * </DVirtualList>
 *
 * <DVirtualList @items={{this.rows}} @estimateSize={{this.estimate}}
 *   @as="ul" @role="listbox" @key="id" @ownedRow={{true}} as |item row|>
 *   <li role="option" {{row.place row.start row.index}} {{row.measure}}>
 *     {{item.label}}
 *   </li>
 * </DVirtualList>
 * ```
 */
export default class DVirtualList<T> extends Component<
  DVirtualListSignature<T>
> {
  container = dElement(this.args.as || "div");
  emptyContainer = dElement(
    ["menu", "ol", "ul"].includes(this.args.as?.toLowerCase() ?? "")
      ? "li"
      : "div"
  );

  /**
   * Makes the inner container a containing block for the absolutely positioned
   * rows. Cleared in the render-all fallback so rows flow normally.
   *
   * Deliberately does NOT set the height. The modifier owns that, because it has
   * to raise it before the engine scrolls and this runs afterwards in the same
   * commit — Glimmer installs a parent's modifier update before a child's, so a
   * height written from tracked state here would land second and overwrite the
   * modifier's with the PREVIOUS flush's total. One writer avoids the collision
   * entirely.
   *
   * This lands as an individual inline property rather than a `style` attribute,
   * so a consumer's own `style` survives. Note the converse is not guaranteed: a
   * consumer passing a DYNAMIC `style` through `...attributes` replaces the whole
   * attribute when it updates, which drops it until the next resize.
   */
  sizeContainer = modifier((element: HTMLElement) => {
    if (!isVirtualizationEnabled()) {
      element.style.removeProperty("position");
      element.style.removeProperty("height");
      return;
    }
    element.style.position = "relative";
  });
  /**
   * Registers a row for height measurement. Runs on insert and re-runs only when
   * the api handle arrives — NOT per-render, so it does not re-measure on every
   * window move, which would fight the engine's prepend-anchor settlement.
   *
   * `measureElement` identifies the row by its `data-index`, which
   * {@link placeRow} stamps, so apply place before measure.
   */
  measureRow = modifier((element: HTMLElement) => {
    this._api?.measureElement(element);
  });
  /**
   * Positions one row: stamps `data-index` (the engine reads it to identify the
   * row) and, while windowing, positions the row absolutely at its virtual
   * offset. Positioning is inert in the render-all fallback, so rows stay in
   * normal flow rather than stacking at `translateY(0)`.
   *
   * One stable modifier DEFINITION shared by every row, applied as
   * `{{row.place row.start row.index}}`. A row that persists across a re-render
   * re-runs its existing instance with new args, where a definition created per
   * row would instead be destroyed and reinstalled — and the destroy can run
   * AFTER the replacement wrote its styles, stripping them off the reused element.
   */
  placeRow = modifier(
    (element: HTMLElement, [start, index]: [start: number, index: number]) => {
      element.dataset.index = String(index);
      if (!isVirtualizationEnabled()) {
        element.style.removeProperty("position");
        element.style.removeProperty("top");
        element.style.removeProperty("inset-inline");
        element.style.removeProperty("transform");
        return;
      }
      element.style.position = "absolute";
      // `top: 0` pins the translate base to the container origin; without it the
      // row translates from its browser-computed static position (nonzero for a
      // later absolute sibling), which silently mis-places every row.
      element.style.top = "0";
      element.style.insetInline = "0";
      element.style.transform = `translateY(${start}px)`;
    }
  );
  @tracked _api: DVirtualListApi | null = null;

  @tracked _virtualItems: readonly VirtualItem[] = [];

  /**
   * Whether rows are windowed. Reads a module-level flag rather than tracked
   * state, so it is fixed for the lifetime of a mounted list — flipping it
   * afterwards does not re-render one that already exists.
   */
  get virtualizationActive() {
    return isVirtualizationEnabled();
  }

  get rows(): Array<RowContext<T>> {
    if (!this.virtualizationActive) {
      // Test / fallback path: render every item in normal flow, no windowing.
      // `keyFor` is the SAME helper the modifier's `getItemKey` uses, so a row keys
      // identically here and in the windowed path.
      return this.args.items.map((item, index) => {
        const key = keyFor(item, this.args.key);
        return this.#rowContext(item, index, key, 0, 0);
      });
    }

    // The window is published from the modifier's after-render flush, so during
    // the render in which `@items` shrank it still describes the PREVIOUS list.
    // Dropping the rows that no longer exist keeps `items[index]` from handing a
    // consumer `undefined` for the one pass before the next flush lands.
    return this._virtualItems
      .filter((vi) => vi.index < this.args.items.length)
      .map((vi) =>
        this.#rowContext(
          this.args.items[vi.index],
          vi.index,
          vi.key,
          vi.start,
          vi.size
        )
      );
  }

  #rowContext(
    item: T,
    index: number,
    key: number | string | bigint,
    start: number,
    size: number
  ): RowContext<T> {
    return {
      item,
      index,
      key,
      start,
      size,
      // Absolute position in the full backing array, never the window offset.
      posinset: this.positionAwareItems ? index + 1 : undefined,
      setSize: this.setSize,
      place: this.placeRow,
      measure: this.measureRow,
    };
  }

  /** Whether `@itemRole` is one of the roles that defines position attributes. */
  get positionAwareItems() {
    return POSITION_AWARE_ROLES.has(this.args.itemRole ?? "");
  }

  /**
   * `"region"` once the viewport carries a name, and otherwise absent.
   *
   * A `div` maps to the `generic` role, which ARIA forbids from carrying a name, so the
   * naming arguments are inert without a role. An unnamed viewport is left alone: an
   * unnamed region is skipped anyway, and a landmark per list would clutter the document.
   */
  get viewportRole() {
    return this.args.viewportLabel || this.args.viewportLabelledBy
      ? "region"
      : undefined;
  }

  /**
   * `-1` once a consumer has opted the viewport out of the tab order, and otherwise absent so
   * the browser keeps its own judgement. Written as an explicit attribute rather than left off,
   * because a scroller a browser has adopted reports `tabIndex === -1` either way — the
   * attribute is what actually suppresses the adoption.
   */
  get viewportTabIndex() {
    return this.args.viewportTabbable === false ? "-1" : undefined;
  }

  /**
   * The true total, which is exactly what a windowed list must publish: the DOM
   * count is a lie, and `-1` ("indeterminable") throws away a number we have.
   * Consumers windowing an unbounded stream pass `@setSize={{-1}}` explicitly.
   */
  get setSize() {
    if (!this.positionAwareItems) {
      return undefined;
    }
    return this.args.setSize ?? this.args.items.length;
  }

  @action
  onState(state: {
    virtualItems: readonly VirtualItem[];
    totalSize: number;
    range: VisibleRange | null;
  }) {
    this._virtualItems = state.virtualItems;
  }

  @action
  onRegisterApi(api: DVirtualListApi) {
    this._api = api;

    // Registration happens once (first-run only), so an initial scroll set up
    // here is inherently applied a single time and never re-fights the user on a
    // later `@items` change. It is deferred a tick because the first flush must
    // size the sizer before the viewport can scroll past its initially empty
    // content.
    //
    // Scheduled before the consumer is handed the API, so a consumer that throws
    // does not take the list's own opening position down with it.
    if (this.args.initialIndex != null) {
      const index = this.args.initialIndex;
      const align = this.args.initialAlign ?? "start";
      next(() => api.scrollToIndex(index, { align }));
    } else if (this.args.anchor === "bottom") {
      // Only the initial rest position. Following subsequent appends is the
      // engine's job, configured by the modifier.
      next(() => api.scrollToEdge("end"));
    }

    this.args.onRegisterApi?.(api);
  }

  <template>
    {{! The outer viewport is the scroll element; the modifier drives it. The
        consumer's role and splattributes go on the inner container, so the
        semantic element owns them. This element takes a role only to carry its own
        name. Size this viewport from CSS. }}
    <div
      class={{dConcatClass "d-virtual-list" @viewportClass}}
      role={{this.viewportRole}}
      aria-label={{if @viewportLabel @viewportLabel}}
      aria-labelledby={{if @viewportLabelledBy @viewportLabelledBy}}
      tabindex={{this.viewportTabIndex}}
      {{dVirtualizer
        items=@items
        estimateSize=@estimateSize
        key=@key
        overscan=@overscan
        anchor=@anchor
        scrollEndThreshold=@scrollEndThreshold
        pinnedIndices=@pinnedIndices
        onState=this.onState
        onRegisterApi=this.onRegisterApi
        onVisibleRangeChange=@onVisibleRangeChange
        onReachStart=@onReachStart
        onReachEnd=@onReachEnd
        edgeThreshold=@edgeThreshold
      }}
    >
      {{! The container always renders, even when empty: a consumer's id and role
          must stay resolvable for anything referencing them from outside. The
          splattributes come first so the role and the sizer win a collision, and
          the sizer writes individual properties rather than a style attribute so a
          consumer's own styling survives. }}
      {{#let this.container this.emptyContainer as |Container EmptyContainer|}}

        <Container
          class="d-virtual-list__sizer"
          ...attributes
          role={{@role}}
          {{this.sizeContainer}}
        >
          {{#if @items.length}}
            {{#each this.rows key="key" as |row|}}
              {{#if @ownedRow}}
                {{yield row.item row}}
              {{else}}
                {{! The role is dynamic, so the linter only sees a bare div and
                    assumes the generic role. Both position attributes are gated at
                    runtime on the roles that define them, and omitted otherwise. }}
                {{! eslint-disable-next-line ember/template-no-unsupported-role-attributes }}
                <div
                  class="d-virtual-list__item"
                  role={{@itemRole}}
                  aria-setsize={{row.setSize}}
                  aria-posinset={{row.posinset}}
                  {{row.place row.start row.index}}
                  {{row.measure}}
                >
                  {{yield row.item row}}
                </div>
              {{/if}}
            {{/each}}
          {{else}}
            <EmptyContainer class="d-virtual-list__empty" role="presentation">
              {{yield to="empty"}}
            </EmptyContainer>
          {{/if}}
        </Container>
      {{/let}}
    </div>
  </template>
}
