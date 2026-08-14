import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import type { TOC } from "@ember/component/template-only";
import { assert } from "@ember/debug";
import { fn, hash } from "@ember/helper";
import { action, get } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import { service } from "@ember/service";
import type A11yService from "discourse/services/a11y";
import { eq } from "discourse/truth-helpers";
import DDragHandle from "discourse/ui-kit/d-drag-handle";
import DReorderButtons from "discourse/ui-kit/d-reorder-buttons";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dElement from "discourse/ui-kit/helpers/d-element";
import dDragAndDropSource, {
  DragSource,
} from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dDragAndDropTarget, {
  DropTargetEvent,
} from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import { i18n } from "discourse-i18n";

/**
 * One normalized move, as both input methods report it. The indices and item
 * arrays all describe the VISIBLE list — the `items` the consumer passed —
 * never a backing store the consumer may keep behind it.
 */
export interface ReorderableMove<T = unknown> {
  /** How the user asked for the move. */
  method: "drag" | "buttons";

  /** The item that moved, resolved against the current items at commit time. */
  item: T;

  /** The list the item left. Always `"default"` for a standalone list. */
  fromList: string;

  /** The list the item entered. Always `"default"` for a standalone list. */
  toList: string;

  /** The item's visible index before the move. */
  fromIndex: number;

  /** The item's visible index after the move. */
  toIndex: number;

  /** The visible items before the move, exactly as passed in `@items`. */
  fromItems: readonly T[];

  /** The visible items before the move; the same array for a single list. */
  toItems: readonly T[];

  /** The proposed visible order after the move. */
  proposedFromItems: readonly T[];

  /** The proposed visible order; the same array for a single list. */
  proposedToItems: readonly T[];
}

/** The per-row state yielded to the default block beside the item. */
export interface ReorderableRowApi {
  /** The row's index in the visible list. */
  index: number;

  /** Whether the row occupies the first movable slot. */
  isFirst: boolean;

  /** Whether the row occupies the last movable slot. */
  isLast: boolean;

  /** Whether the row can be reordered at all. */
  movable: boolean;

  /** Whether this row's drag is currently in flight. */
  isDragging: boolean;
}

/** The context handed to a `@rowClass` function. */
interface RowClassContext {
  index: number;
  movable: boolean;
}

/**
 * The internal per-row view model the component renders from. Rows are
 * recomputed from `@items` on every relevant change, so anything an event
 * handler needs later is re-resolved by `key` rather than captured.
 */
interface Row<T> {
  item: T;
  key: string;
  index: number;
  movable: boolean;
  isFirst: boolean;
  isLast: boolean;
  isDragging: boolean;
  disableUp: boolean;
  disableDown: boolean;
  handleLabel: string;
  upLabel: string;
  downLabel: string;
}

interface DReorderableListSignature<T> {
  Args: {
    /**
     * The visible items in display order. The component reasons, indexes, and
     * announces only in this list; projecting a reorder onto hidden backing
     * storage stays with the consumer. Never mutated by the component.
     */
    items: readonly T[];

    /**
     * Property path resolving each item's stable identity, used for keyed
     * rendering and for resolving drag payloads at drop time. The literal
     * value `"@index"` opts into index-based identity for primitive
     * collections whose values may repeat. Omitted, object identity is used,
     * which is only safe when the same objects are passed on every render.
     */
    key?: string;

    /**
     * Translated display name for an item. It names the drag handle, both
     * arrow buttons, and the post-move announcement, so every control stays
     * distinguishable when read out of context.
     */
    label: (item: T) => string;

    /**
     * The single move callback. Pointer drops and arrow presses both arrive
     * here, already normalized and no-op-suppressed. Return `false` to veto
     * the announcement; the consumer then owns whatever feedback replaces it.
     */
    onMove: (move: ReorderableMove<T>) => void | false;

    /**
     * Rows failing this predicate are frozen: they render no controls, are
     * not drag sources, refuse drops, and keep their exact visible index in
     * every proposed order. Arrow moves hop over them. Defaults to every row
     * being movable.
     */
    movable?: (item: T) => boolean;

    /**
     * When true, the boundary arrows stay enabled and a move past either end
     * carries the item around to the other one. The default keeps boundary
     * arrows visible but marked unavailable, which is how a keyboard user
     * learns they reached an end without losing their place.
     */
    wrap?: boolean;

    /** Tag name for the list element. Defaults to `"ul"`. */
    tag?: string;

    /** Tag name for each row element. Defaults to `"li"`. */
    itemTag?: string;

    /** Optional ARIA role for the list element. */
    role?: string;

    /** Optional ARIA role for each row element. */
    itemRole?: string;

    /**
     * Extra class(es) for the row element: a static string, or a function of
     * the item and its `{ index, movable }` state.
     */
    rowClass?: string | ((item: T, context: RowClassContext) => string);

    /**
     * Where the standard controls render relative to the row's block content.
     * Defaults to `"start"`.
     */
    controls?: "start" | "end";

    /**
     * Layout for the arrow pair, forwarded to the underlying buttons: the
     * stacked default, or `"inline"` for short rows the stacked pair would
     * stretch.
     */
    arrowsLayout?: "stacked" | "inline";

    /**
     * `"reveal"` marks the list so styling can show controls only on row
     * hover or focus-within; the default keeps them always visible. The
     * controls stay in the tab order either way — reveal is presentation,
     * never reachability.
     */
    controlsVisibility?: "always" | "reveal";

    /**
     * Read-only mode: rows render without controls and without any drag
     * wiring, as if every row were frozen.
     */
    disabled?: boolean;

    /**
     * Overrides the announcement for a committed move. Return the text to
     * announce, or `false` to suppress the announcement entirely. `onMove`
     * has already run either way.
     */
    announceMove?: (move: ReorderableMove<T>) => string | false;
  };
  Blocks: {
    /** The row content, rendered beside the standard controls. */
    default: [item: T, row: ReorderableRowApi];

    /** Rendered inside the list element, before every row. */
    header: [];

    /**
     * Rendered inside the list element, after every row — for content that
     * shares the container but sits outside the reorderable set.
     */
    static: [];

    /** Rendered in the rows' position when `@items` is empty. */
    empty: [];
  };
  Element: HTMLElement;
}

interface ReorderControlsSignature {
  Args: {
    row: Row<unknown>;
    dragType: string;
    arrowsLayout?: "stacked" | "inline";
    onDragStart: (event: { source: DragSource }) => void;
    onDragEnd: () => void;
    moveRow: (key: string, direction: "up" | "down") => void;
  };
}

/**
 * The standard per-row controls: the decorative drag handle and the arrow
 * pair. Extracted so the start and end placements render one shared shape.
 *
 * The drag source registers on the handle itself, so the handle is both what
 * carries `draggable` and what the registration marks — the row stays free
 * for text selection and nested controls without any ref plumbing.
 */
const ReorderControls: TOC<ReorderControlsSignature> = <template>
  <DDragHandle
    {{dDragAndDropSource
      type=@dragType
      data=(hash key=@row.key)
      onDragStart=@onDragStart
      onDragEnd=@onDragEnd
    }}
    @label={{@row.handleLabel}}
    class="d-reorderable-list__handle"
  />
  <DReorderButtons
    @onMoveUp={{fn @moveRow @row.key "up"}}
    @onMoveDown={{fn @moveRow @row.key "down"}}
    @disableUp={{@row.disableUp}}
    @disableDown={{@row.disableDown}}
    @upLabel={{@row.upLabel}}
    @downLabel={{@row.downLabel}}
    @layout={{@arrowsLayout}}
    class="d-reorderable-list__arrows"
  />
</template>;

/**
 * A reorderable list: the standard shell for any surface where the user
 * changes the order of visible rows.
 *
 * The component owns the whole interaction — keyed iteration, the drag
 * handle, the arrow-button keyboard path, boundary state, drop normalization,
 * no-op suppression, and the screen-reader announcement — so a consumer
 * supplies only its row content and one `@onMove` that projects the proposed
 * visible order into its own store. Both input methods converge on a single
 * commit: one callback and one announcement per real move, and neither for a
 * move that lands where it started.
 *
 * The list and row elements stay stylable and semantically flexible through
 * `@tag` / `@itemTag` / `@role` / `@itemRole`, which is what lets one
 * component serve plain lists and ARIA table shapes alike.
 *
 * @example
 * ```gjs
 * <DReorderableList
 *   @items={{this.sections}}
 *   @key="id"
 *   @label={{this.sectionLabel}}
 *   @onMove={{this.applyMove}}
 *   class="my-sections"
 *   as |section|
 * >
 *   <span>{{section.name}}</span>
 * </DReorderableList>
 * ```
 */
export default class DReorderableList<T> extends Component<
  DReorderableListSignature<T>
> {
  @service declare a11y: A11yService;

  /**
   * The drag discriminator for this list. Generated per instance, so two
   * unrelated lists on one page can never accept each other's drags.
   */
  dragType = `d-reorderable-list:${guidFor(this)}`;
  rowClassFor = (row: Row<T>): string | undefined => {
    const { rowClass } = this.args;
    if (typeof rowClass === "function") {
      return rowClass(row.item, { index: row.index, movable: row.movable });
    }
    return rowClass;
  };
  /**
   * The key of the row whose drag is in flight, so every row can yield its
   * own `isDragging`. Keyed rather than held as an element or item reference,
   * because the host may replace its items mid-drag.
   */
  @tracked _draggingKey: string | null = null;

  get listTag(): string {
    return this.args.tag ?? "ul";
  }

  get itemTag(): string {
    return this.args.itemTag ?? "li";
  }

  get controlsPlacement(): "start" | "end" {
    return this.args.controls ?? "start";
  }

  get revealControls(): boolean {
    return this.args.controlsVisibility === "reveal";
  }

  /**
   * The per-row view models: identity, movability, boundary state, and the
   * translated control labels, computed in one pass so the template and the
   * event handlers read one consistent projection of `@items`.
   */
  get rows(): Row<T>[] {
    const { disabled, items, label, movable, wrap } = this.args;
    const seen = new Set<string>();

    const rows = items.map((item, index) => {
      const key = this.#keyFor(item, index);
      assert(
        `d-reorderable-list: duplicate row key "${key}" — every item needs a unique key`,
        !seen.has(key)
      );
      seen.add(key);

      const itemLabel = label(item);
      return {
        item,
        key,
        index,
        movable: !disabled && (movable ? movable(item) : true),
        isFirst: false,
        isLast: false,
        isDragging: key === this._draggingKey,
        disableUp: false,
        disableDown: false,
        handleLabel: i18n("reorder.drag_handle", { label: itemLabel }),
        upLabel: i18n("reorder.move_up", { label: itemLabel }),
        downLabel: i18n("reorder.move_down", { label: itemLabel }),
      };
    });

    const movableRows = rows.filter((row) => row.movable);
    for (const [seqIndex, row] of movableRows.entries()) {
      row.isFirst = seqIndex === 0;
      row.isLast = seqIndex === movableRows.length - 1;
      row.disableUp = !wrap && row.isFirst;
      row.disableDown = !wrap && row.isLast;
    }

    return rows;
  }

  @action
  onSourceDragStart({ source }: { source: DragSource }) {
    this._draggingKey = source.data.key as string;
  }

  @action
  onSourceDragEnd() {
    this._draggingKey = null;
  }

  /**
   * The arrow-button path: one step within the movable subsequence, wrapping
   * around the ends when `@wrap` asks for it.
   *
   * Resolved fresh by key rather than acting on the row object the render
   * captured, because a press commits against the list as it stands now.
   *
   * @param key - The pressed row's key.
   * @param direction - Which arrow was pressed.
   */
  @action
  moveRow(key: string, direction: "up" | "down") {
    const rows = this.rows;
    const row = rows.find((candidate) => candidate.key === key);
    if (!row?.movable) {
      return;
    }

    const seq = rows.filter((candidate) => candidate.movable);
    const from = seq.indexOf(row);
    let to = direction === "up" ? from - 1 : from + 1;

    if (this.args.wrap) {
      to = (to + seq.length) % seq.length;
    } else if (to < 0 || to >= seq.length) {
      return;
    }

    this.#commitSeqMove("buttons", rows, seq, from, to);
  }

  /**
   * The drop path for one row target. The payload carries only the dragged
   * row's key; the item and both indices are resolved against the current
   * rows here, so a host that replaced its items mid-drag still lands the
   * drop on the right thing — or refuses it when the key is gone.
   *
   * @param targetKey - The key of the row the drop landed on.
   * @param event - The target modifier's drop payload.
   */
  @action
  onRowDrop(targetKey: string, { position, source }: DropTargetEvent) {
    const rows = this.rows;
    const sourceRow = rows.find(
      (candidate) => candidate.key === source.data.key
    );
    const targetRow = rows.find((candidate) => candidate.key === targetKey);
    if (!sourceRow?.movable || !targetRow?.movable) {
      return;
    }

    const seq = rows.filter((candidate) => candidate.movable);
    const from = seq.indexOf(sourceRow);
    let to = seq.indexOf(targetRow);
    if (position === "after") {
      to += 1;
    }
    if (from < to) {
      to -= 1;
    }

    this.#commitSeqMove("drag", rows, seq, from, to);
  }

  #keyFor(item: T, index: number): string {
    const { key } = this.args;
    if (key === "@index") {
      return String(index);
    }
    if (key) {
      return String(get(item as object, key));
    }
    return guidFor(item);
  }

  /**
   * The single commit both input methods funnel into: splices the move within
   * the movable subsequence, re-interleaves it with the frozen rows (which
   * keep their exact visible indices), suppresses no-ops, calls `@onMove`
   * once, and announces once.
   *
   * @param method - Which input method asked for the move.
   * @param rows - The current row projection.
   * @param seq - The movable rows, in visible order.
   * @param from - The item's index within `seq`.
   * @param to - The destination index within `seq`.
   */
  #commitSeqMove(
    method: ReorderableMove<T>["method"],
    rows: Row<T>[],
    seq: Row<T>[],
    from: number,
    to: number
  ) {
    if (to === from) {
      return;
    }

    const moved = seq[from]!;
    const nextSeq = [...seq];
    nextSeq.splice(from, 1);
    nextSeq.splice(to, 0, moved);

    // Frozen rows keep their visible slots; the movable slots are refilled in
    // the new subsequence order.
    let cursor = 0;
    const proposed = rows.map((row) =>
      row.movable ? nextSeq[cursor++]!.item : row.item
    );
    const toIndex = seq[to]!.index;

    const { items } = this.args;
    const move: ReorderableMove<T> = {
      method,
      item: moved.item,
      fromList: "default",
      toList: "default",
      fromIndex: moved.index,
      toIndex,
      fromItems: items,
      toItems: items,
      proposedFromItems: proposed,
      proposedToItems: proposed,
    };

    if (this.args.onMove(move) === false) {
      return;
    }

    let message: string;
    if (this.args.announceMove) {
      const custom = this.args.announceMove(move);
      if (custom === false) {
        return;
      }
      message = custom;
    } else {
      message = i18n("reorder_announcement", {
        label: this.args.label(moved.item),
        position: toIndex + 1,
        total: proposed.length,
      });
    }

    this.a11y.announce(message);
  }

  <template>
    {{#let (dElement this.listTag) as |List|}}
      <List
        class={{dConcatClass
          "d-reorderable-list"
          (if this.revealControls "--reveal-controls")
        }}
        role={{@role}}
        ...attributes
      >
        {{yield to="header"}}
        {{#if this.rows.length}}
          {{#let (dElement this.itemTag) as |Item|}}
            {{#each this.rows key="key" as |row|}}
              {{! Two whole-row branches rather than one row with a conditional
                  modifier: a conditionally curried modifier is re-created every
                  time the rows recompute, and re-installing the drop target
                  mid-drag leaves the element with a dead registration. Applied
                  statically, the target registers once per row element. }}
              {{#if row.movable}}
                <Item
                  class={{dConcatClass
                    "d-reorderable-list__row"
                    (this.rowClassFor row)
                  }}
                  role={{@itemRole}}
                  data-reorderable-key={{row.key}}
                  {{dDragAndDropTarget
                    accepts=this.dragType
                    onDrop=(fn this.onRowDrop row.key)
                  }}
                >
                  {{#if (eq this.controlsPlacement "start")}}
                    <ReorderControls
                      @row={{row}}
                      @dragType={{this.dragType}}
                      @arrowsLayout={{@arrowsLayout}}
                      @onDragStart={{this.onSourceDragStart}}
                      @onDragEnd={{this.onSourceDragEnd}}
                      @moveRow={{this.moveRow}}
                    />
                  {{/if}}
                  {{yield
                    row.item
                    (hash
                      index=row.index
                      isFirst=row.isFirst
                      isLast=row.isLast
                      movable=row.movable
                      isDragging=row.isDragging
                    )
                  }}
                  {{#if (eq this.controlsPlacement "end")}}
                    <ReorderControls
                      @row={{row}}
                      @dragType={{this.dragType}}
                      @arrowsLayout={{@arrowsLayout}}
                      @onDragStart={{this.onSourceDragStart}}
                      @onDragEnd={{this.onSourceDragEnd}}
                      @moveRow={{this.moveRow}}
                    />
                  {{/if}}
                </Item>
              {{else}}
                <Item
                  class={{dConcatClass
                    "d-reorderable-list__row"
                    (this.rowClassFor row)
                  }}
                  role={{@itemRole}}
                  data-reorderable-key={{row.key}}
                >
                  {{yield
                    row.item
                    (hash
                      index=row.index
                      isFirst=row.isFirst
                      isLast=row.isLast
                      movable=row.movable
                      isDragging=row.isDragging
                    )
                  }}
                </Item>
              {{/if}}
            {{/each}}
          {{/let}}
        {{else}}
          {{yield to="empty"}}
        {{/if}}
        {{yield to="static"}}
      </List>
    {{/let}}
  </template>
}
