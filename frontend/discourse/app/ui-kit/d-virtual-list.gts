import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { trustHTML } from "@ember/template";
import { modifier } from "ember-modifier";
import {
  isVirtualizationEnabled,
  stableKeyFor,
} from "discourse/ui-kit/lib/virtualizer";
import dVirtualizer from "discourse/ui-kit/modifiers/d-virtualizer";

/** A single measured/positioned row exposed to the default block. */
interface VirtualItem {
  key: number | string | bigint;
  index: number;
  start: number;
  size: number;
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
    /** Extra rows rendered above/below the viewport to cut mount churn (default 5). */
    overscan?: number;
    /** `"bottom"` rests at, and follows, the end (chat). Default `"top"`. */
    anchor?: "top" | "bottom";
    /**
     * Role for the scroll container, e.g. `"listbox"` or `"feed"`. Omitted by
     * default: a role is a promise about keyboard behaviour the primitive does
     * not implement on the consumer's behalf, so the consumer opts in.
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
  };
  Blocks: {
    default: [item: T, virtualItem: VirtualItem];
    empty: [];
  };
  Element: HTMLDivElement;
}

/**
 * Renders only a window of a large list while keeping the DOM bounded, backed by
 * `@tanstack/virtual-core` behind the ui-kit library wall.
 *
 * The component owns the tracked window (`_virtualItems`/`_totalSize`); the
 * `dVirtualizer` modifier owns the engine and pushes state in through `onState`.
 * Each row is wrapped in an a11y-annotated, measured `.d-virtual-list__item`, so
 * consumers only yield row content.
 *
 * @example
 * ```gjs
 * <DVirtualList @items={{this.rows}} @estimateSize={{this.estimate}} as |row|>
 *   <MyRow @row={{row}} />
 * </DVirtualList>
 * ```
 */
export default class DVirtualList<T> extends Component<
  DVirtualListSignature<T>
> {
  @tracked api: DVirtualListApi | null = null;
  measureRow = modifier((element: HTMLElement) => {
    // Reading `this.api` autotracks it, so this re-runs once the handle arrives
    // (the scroll-element modifier may register it after the first rows render).
    this.api?.measureElement(element);
  });
  @tracked _virtualItems: VirtualItem[] = [];
  @tracked _totalSize = 0;

  get virtualizationActive() {
    return isVirtualizationEnabled();
  }

  get rows() {
    // `aria-posinset` is only meaningful on a role that defines it; on anything
    // else AT discards it, so it is left off rather than emitted as noise.
    const positioned = this.positionAwareItems;

    if (!this.virtualizationActive) {
      // Test / fallback path: render every item in normal flow, no windowing.
      return this.args.items.map((item, index) => ({
        key: stableKeyFor(item),
        item,
        index,
        posinset: positioned ? index + 1 : undefined,
        virtualItem: { key: stableKeyFor(item), index, start: 0, size: 0 },
      }));
    }

    return this._virtualItems.map((vi) => ({
      key: vi.key,
      item: this.args.items[vi.index],
      index: vi.index,
      // Absolute position in the full backing array, never the window offset.
      posinset: positioned ? vi.index + 1 : undefined,
      virtualItem: vi,
    }));
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

  get spacerStyle() {
    if (!this.virtualizationActive) {
      return trustHTML("");
    }
    return trustHTML(
      `position: relative; width: 100%; height: ${this._totalSize}px;`
    );
  }

  get windowStyle() {
    if (!this.virtualizationActive) {
      return trustHTML("");
    }
    const start = this._virtualItems[0]?.start ?? 0;
    return trustHTML(
      `position: absolute; top: 0; left: 0; width: 100%; transform: translateY(${start}px);`
    );
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

    if (this.args.anchor === "bottom") {
      // Initial rest at the live edge. Continuous follow is layered on top of this.
      next(() => api.scrollToEdge("end"));
    }
  }

  <template>
    <div
      class="d-virtual-list"
      role={{@role}}
      ...attributes
      {{dVirtualizer
        items=@items
        estimateSize=@estimateSize
        overscan=@overscan
        anchor=@anchor
        onState=this.onState
        onRegisterApi=this.onRegisterApi
        onVisibleRangeChange=@onVisibleRangeChange
      }}
    >
      {{#if @items.length}}
        <div
          class="d-virtual-list__spacer"
          role="presentation"
          style={{this.spacerStyle}}
        >
          <div
            class="d-virtual-list__window"
            role="presentation"
            style={{this.windowStyle}}
          >
            {{#each this.rows key="key" as |row|}}
              {{! The role is dynamic, so the linter can only see a bare div and
                  assumes the implicit generic role. Both attributes are gated at
                  runtime on POSITION_AWARE_ROLES, and are undefined (so omitted)
                  unless @itemRole is one that actually supports them. }}
              {{! eslint-disable-next-line ember/template-no-unsupported-role-attributes }}
              <div
                class="d-virtual-list__item"
                role={{@itemRole}}
                aria-setsize={{this.setSize}}
                aria-posinset={{row.posinset}}
                data-index={{row.index}}
                {{this.measureRow}}
              >
                {{yield row.item row.virtualItem}}
              </div>
            {{/each}}
          </div>
        </div>
      {{else}}
        {{yield to="empty"}}
      {{/if}}
    </div>
  </template>
}
