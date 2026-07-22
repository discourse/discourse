import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import type { ModifierLike } from "@glint/template";
import { modifier } from "ember-modifier";
import dElement from "discourse/ui-kit/helpers/d-element";
import {
  isVirtualizationEnabled,
  keyFor,
} from "discourse/ui-kit/lib/virtualizer";
import dVirtualizer from "discourse/ui-kit/modifiers/d-virtualizer";

/** A single measured/positioned row exposed to the default block. */
interface VirtualItem {
  key: number | string | bigint;
  index: number;
  start: number;
  size: number;
}

/**
 * The per-row context yielded as the block's second parameter. In `@ownedRow`
 * mode the consumer renders the row element itself and applies `{{row.place}}`
 * (positioning) and `{{row.measure}}` (measurement); simple consumers can ignore
 * it and let the primitive wrap their content.
 */
/**
 * The positioning modifier, applied as `{{row.place row.start row.index}}`. It is
 * a STABLE reference shared by every row (not a fresh per-row modifier), so a
 * re-render UPDATES the one instance rather than destroying and reinstalling it —
 * which would let the old instance's cleanup strip the new one's styles off a
 * reused element. Its positional args carry the row's offset and absolute index.
 */
type PlaceModifier = ModifierLike<{
  Element: HTMLElement;
  Args: { Positional: [start: number, index: number] };
}>;

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
   */
  place: PlaceModifier;
  /** Registers the row for height measurement. Arg-less and stable; apply once per row. */
  measure: ModifierLike<HTMLElement>;
}

/** The imperative handle registered via `@onRegisterApi`. */
export interface DVirtualListApi {
  scrollToIndex(
    index: number,
    opts?: {
      align?: "start" | "center" | "end" | "auto";
      behavior?: ScrollBehavior;
    }
  ): void;
  scrollToOffset(offset: number, opts?: object): void;
  scrollToEdge(edge: "start" | "end"): void;
  measure(): void;
  measureElement(element: HTMLElement): void;
  visibleRange(): { startIndex: number; endIndex: number } | undefined;
  readonly isScrolling: boolean;
}

interface VisibleRange {
  startIndex: number;
  endIndex: number;
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
    /** The full backing array. Only a window is rendered; it is never sliced. */
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
     * the rows (the semantic element — e.g. `"ul"` for a listbox). Default `"div"`.
     * The OUTER `.d-virtual-list` scroll viewport stays role-less; size it via CSS.
     */
    as?: string;
    /**
     * When set, the default block yields `[item, rowContext]` and the CONSUMER
     * renders the row element, applying `{{rowContext.place}}` + `{{rowContext.measure}}`
     * (no wrapper, native semantic rows). When omitted, the primitive wraps the
     * yielded content in its own measured, `@itemRole`-stamped row element.
     */
    ownedRow?: boolean;
    /** `"bottom"` rests at, and follows, the end (chat). Default `"top"`. */
    anchor?: "top" | "bottom";
    /**
     * On the FIRST render only, scroll so this absolute index is revealed (per
     * `@initialAlign`) — a flash-free open onto a deep selection. Applied once at
     * mount; a later `@items` change never re-scrolls, so it cannot fight the
     * user. Takes precedence over `@anchor="bottom"`.
     */
    initialIndex?: number;
    /** Alignment for `@initialIndex` within the viewport. Default `"start"`. */
    initialAlign?: "start" | "center" | "end" | "auto";
    /**
     * An absolute index kept mounted even when scrolled out of the window, so a
     * keyboard-active row's `aria-activedescendant` id never dangles. The pinned
     * row is merged into the window in ascending index order (DOM order stays
     * monotonic by `data-index`).
     */
    pinnedIndex?: number;
    /**
     * Role for the inner container (the semantic element), e.g. `"listbox"` or
     * `"feed"`. Omitted by default: a role is a promise about keyboard behaviour
     * the primitive does not implement on the consumer's behalf, so the consumer
     * opts in. The outer `.d-virtual-list` scroll viewport stays role-less.
     */
    role?: string;
    /**
     * Role for each row wrapper, e.g. `"option"`. ARIA roles override native
     * element semantics, so a `div` row with `role="option"` inside a
     * `role="listbox"` container is valid.
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
    default: [item: T, row: RowContext<T>];
    empty: [];
  };
  Element: HTMLElement;
}

/**
 * Renders only a window of a large list while keeping the DOM bounded, backed by
 * `@tanstack/virtual-core` behind the ui-kit library wall.
 *
 * Structure: an outer role-less `.d-virtual-list` scroll VIEWPORT (the element the
 * `dVirtualizer` modifier drives) wraps an inner `@as` CONTAINER — the semantic
 * element that carries `@role`/`...attributes` and is the sizer (`height` = the
 * full total) — whose direct children are the rows, each absolutely positioned to
 * its virtual offset. The component owns the tracked window (`_virtualItems`/
 * `_totalSize`); the modifier owns the engine and pushes state in through `onState`.
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
  @tracked api: DVirtualListApi | null = null;

  // Sizes the inner container by writing ONLY the properties the virtualizer needs
  // — a relative containing block for the absolute rows, plus the full height so the
  // scrollbar is honest — leaving any consumer `style` untouched (unlike a `style=`
  // attribute, which `...attributes` would clobber). Cleared in the render-all
  // fallback so rows flow normally.
  sizeContainer = modifier((element: HTMLElement) => {
    if (!isVirtualizationEnabled()) {
      element.style.removeProperty("position");
      element.style.removeProperty("width");
      element.style.removeProperty("height");
      return;
    }
    element.style.position = "relative";
    element.style.width = "100%";
    element.style.height = `${this._totalSize}px`;
  });

  // Registers a row for height measurement. STABLE (one instance per element, run
  // on insert and re-run only when the api handle arrives) — NOT per-render, so it
  // does not re-measure on every window move, which would fight the engine's
  // prepend-anchor settlement. `measureElement` identifies the row by its
  // `data-index`, which `{{row.place}}` stamps, so apply place before measure.
  measureRow = modifier((element: HTMLElement) => {
    this.api?.measureElement(element);
  });

  // Positions one row: stamps `data-index` (virtual-core's `measureElement` reads
  // it to identify the row) and, while windowing, positions the row absolutely at
  // its virtual offset. INERT positioning in the render-all fallback (rows stay in
  // normal flow rather than stacking at `translateY(0)`).
  //
  // STABLE and arg-driven: one instance shared by every row, applied as
  // `{{row.place row.start row.index}}`. A row that persists across a re-render
  // keeps this same instance and merely re-runs with new args — where a fresh
  // per-row modifier would be destroyed and reinstalled, and the destroy could run
  // AFTER the new one wrote its styles, stripping them off the reused element.
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

  @tracked _virtualItems: VirtualItem[] = [];
  @tracked _totalSize = 0;

  get virtualizationActive() {
    return isVirtualizationEnabled();
  }

  get rows(): Array<RowContext<T> & { posinset: number | undefined }> {
    if (!this.virtualizationActive) {
      // Test / fallback path: render every item in normal flow, no windowing.
      // `keyFor` is the SAME helper the modifier's `getItemKey` uses, so a row keys
      // identically here and in the windowed path.
      return this.args.items.map((item, index) => {
        const key = keyFor(item, this.args.key);
        return this.#rowContext(item, index, key, 0, 0);
      });
    }

    return this._virtualItems.map((vi) =>
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
  ): RowContext<T> & { posinset: number | undefined } {
    return {
      item,
      index,
      key,
      start,
      size,
      // `aria-posinset` is only meaningful on a role that defines it; on anything
      // else AT discards it. Absolute position in the full backing array, never the
      // window offset — the wrapped path stamps it; owned rows carry their own.
      posinset: this.positionAwareItems ? index + 1 : undefined,
      place: this.placeRow,
      measure: this.measureRow,
    };
  }

  // The inner container tag (the semantic element carrying `@role`/`...attributes`
  // and the rows). `dElement` types `...attributes` against the chosen tag.
  get container() {
    return dElement(this.args.as ?? "div");
  }

  /**
   * `aria-setsize`/`aria-posinset` are only defined on a handful of roles. On any
   * other element AT drops them, so emitting them unconditionally is noise.
   */
  get positionAwareItems() {
    return POSITION_AWARE_ROLES.has(this.args.itemRole ?? "");
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
    virtualItems: VirtualItem[];
    totalSize: number;
    range: VisibleRange | null;
  }) {
    this._virtualItems = state.virtualItems;
    this._totalSize = state.totalSize;
  }

  @action
  onRegisterApi(api: DVirtualListApi) {
    this.api = api;
    this.args.onRegisterApi?.(api);

    // Registration happens once (first-run only), so an initial scroll set up
    // here is inherently applied a single time and never re-fights the user on a
    // later `@items` change. It is deferred a tick because the first flush must
    // publish `_totalSize` and the sizer must take that height before the
    // viewport can scroll past its (initially zero) content.
    if (this.args.initialIndex != null) {
      const index = this.args.initialIndex;
      const align = this.args.initialAlign ?? "start";
      next(() => api.scrollToIndex(index, { align }));
    } else if (this.args.anchor === "bottom") {
      // Initial rest at the live edge. Continuous follow is layered on top of this.
      next(() => api.scrollToEdge("end"));
    }
  }

  <template>
    {{! The OUTER viewport is the scroll element (role-less); the modifier drives it.
        `@role` + `...attributes` go on the INNER container so the semantic element
        (e.g. a listbox) owns them. Size this viewport via CSS, not `...attributes`. }}
    <div
      class="d-virtual-list"
      {{dVirtualizer
        items=@items
        estimateSize=@estimateSize
        key=@key
        overscan=@overscan
        anchor=@anchor
        pinnedIndex=@pinnedIndex
        onState=this.onState
        onRegisterApi=this.onRegisterApi
        onVisibleRangeChange=@onVisibleRangeChange
        onReachStart=@onReachStart
        onReachEnd=@onReachEnd
        edgeThreshold=@edgeThreshold
      }}
    >
      {{! The container ALWAYS renders — an empty listbox still needs its id/role so
          a combobox's `aria-controls` resolves. `...attributes` come first so that
          `@role` and the sizer win over any consumer collision; the sizer is applied
          as a modifier (individual properties) so a consumer `style` cannot clobber
          the position/height the virtualizer depends on. }}
      {{#let this.container as |Container|}}

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
                    assumes the generic role. Both a11y attributes are gated at
                    runtime on POSITION_AWARE_ROLES and omitted unless @itemRole
                    supports them; the place modifier stamps data-index. }}
                {{! eslint-disable-next-line ember/template-no-unsupported-role-attributes }}
                <div
                  class="d-virtual-list__item"
                  role={{@itemRole}}
                  aria-setsize={{this.setSize}}
                  aria-posinset={{row.posinset}}
                  {{row.place row.start row.index}}
                  {{row.measure}}
                >
                  {{yield row.item row}}
                </div>
              {{/if}}
            {{/each}}
          {{else}}
            {{yield to="empty"}}
          {{/if}}
        </Container>
      {{/let}}
    </div>
  </template>
}
