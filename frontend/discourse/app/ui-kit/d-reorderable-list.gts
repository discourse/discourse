import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import type { TOC } from "@ember/component/template-only";
import { assert } from "@ember/debug";
import { isDestroyed, isDestroying } from "@ember/destroyable";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, get } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import { next, schedule } from "@ember/runloop";
import { service } from "@ember/service";
import type { ComponentLike, ModifierLike } from "@glint/template";
import { modifier } from "ember-modifier";
import type A11yService from "discourse/services/a11y";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
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

  /**
   * The pre-wired drag handle for this row, present only under
   * `@controls="manual"` on a movable row. Placing it anywhere inside the row
   * block renders the standard handle; omitting it makes the row a
   * keyboard-only surface.
   */
  handle?: ComponentLike<{ Element: HTMLSpanElement }>;

  /**
   * The pre-wired arrow pair for this row, present only under
   * `@controls="manual"` on a movable row. A movable manual row must place
   * either this or `controls` — the keyboard path is not optional, and a
   * development assertion fires when both are missing.
   */
  arrows?: ComponentLike<{ Element: HTMLSpanElement }>;

  /**
   * The handle and arrows fused in their standard order, for manual
   * placements that keep both controls in one cell.
   */
  controls?: ComponentLike<object>;
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
  yieldControls: boolean;
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
     *
     * Index identity is positional by definition: after a move, rows keep
     * their positions while items flow through them, so focus and drag state
     * stay with a position rather than following the moved item. That is how
     * position-addressed value lists already behave, and is the trade-off
     * accepted when items carry no identity of their own.
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

    /**
     * Optional ARIA role for each row element. Use roles that permit
     * interactive descendants (such as `row`): a role whose children are
     * presentational (`option`, `menuitem`, `tab`) flattens the rendered
     * controls out of the accessibility tree.
     */
    itemRole?: string;

    /**
     * Extra class(es) for the row element: a static string, or a function of
     * the item and its `{ index, movable }` state.
     */
    rowClass?: string | ((item: T, context: RowClassContext) => string);

    /**
     * Where the standard controls render relative to the row's block content.
     * `"start"` (the default) and `"end"` render them automatically;
     * `"manual"` renders none and instead yields pre-wired `handle`, `arrows`,
     * and `controls` components on the row API, for layouts where the
     * controls must occupy specific cells or grid tracks.
     */
    controls?: "start" | "end" | "manual";

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

    /**
     * Renders a create affordance after the rows: a text input and an add
     * button by default, or the `<:create>` block when one is given.
     */
    allowCreate?: boolean;

    /**
     * Called with the trimmed value when the default create affordance is
     * submitted. Never called for an empty or whitespace-only value.
     */
    onCreate?: (value: string) => void;
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

    /**
     * Replaces the default create affordance when `@allowCreate` is set,
     * rendered between the rows and the static content.
     */
    create: [];
  };
  Element: HTMLElement;
}

interface HandlePartSignature {
  Args: {
    row: Row<unknown>;
    dragType: string;
    onDragStart: (event: { source: DragSource }) => void;
    onDragEnd: () => void;
  };
  Element: HTMLSpanElement;
}

/**
 * The standard drag handle for one row.
 *
 * The drag source registers on the handle itself, so the handle is both what
 * carries `draggable` and what the registration marks — the row stays free
 * for text selection and nested controls without any ref plumbing.
 */
const HandlePart: TOC<HandlePartSignature> = <template>
  <DDragHandle
    {{dDragAndDropSource
      type=@dragType
      data=(hash key=@row.key)
      onDragStart=@onDragStart
      onDragEnd=@onDragEnd
    }}
    @label={{@row.handleLabel}}
    class="d-reorderable-list__handle"
    ...attributes
  />
</template>;

interface ArrowsPartSignature {
  Args: {
    row: Row<unknown>;
    arrowsLayout?: "stacked" | "inline";
    moveRow: (key: string, direction: "up" | "down") => void;
    register: ModifierLike<{ Args: { Positional: [string] } }>;
  };
  Element: HTMLSpanElement;
}

/**
 * The standard arrow pair for one row. It reports its presence through
 * `@register`, which is how the manual-placement guard knows the row kept its
 * keyboard path.
 */
const ArrowsPart: TOC<ArrowsPartSignature> = <template>
  <DReorderButtons
    {{@register @row.key}}
    @onMoveUp={{fn @moveRow @row.key "up"}}
    @onMoveDown={{fn @moveRow @row.key "down"}}
    @disableUp={{@row.disableUp}}
    @disableDown={{@row.disableDown}}
    @upLabel={{@row.upLabel}}
    @downLabel={{@row.downLabel}}
    @layout={{@arrowsLayout}}
    class="d-reorderable-list__arrows"
    ...attributes
  />
</template>;

interface ReorderControlsSignature {
  Args: {
    row: Row<unknown>;
    dragType: string;
    arrowsLayout?: "stacked" | "inline";
    onDragStart: (event: { source: DragSource }) => void;
    onDragEnd: () => void;
    moveRow: (key: string, direction: "up" | "down") => void;
    register: ModifierLike<{ Args: { Positional: [string] } }>;
  };
}

/**
 * The standard per-row controls: the decorative drag handle and the arrow
 * pair, in their fixed order. The automatic placements render this shape, and
 * a manual placement receives it as the fused `controls` component.
 */
const ReorderControls: TOC<ReorderControlsSignature> = <template>
  <HandlePart
    @row={{@row}}
    @dragType={{@dragType}}
    @onDragStart={{@onDragStart}}
    @onDragEnd={{@onDragEnd}}
  />
  <ArrowsPart
    @row={{@row}}
    @arrowsLayout={{@arrowsLayout}}
    @moveRow={{@moveRow}}
    @register={{@register}}
  />
</template>;

interface CreateRowSignature {
  Args: {
    itemTag: string;
    onCreate?: (value: string) => void;
  };
}

/**
 * The default create affordance: a text input and an add button rendered as
 * one extra row. Submitting via Enter or the button reports the trimmed value
 * and clears the input; an empty or whitespace-only value reports nothing.
 */
class CreateRow extends Component<CreateRowSignature> {
  captureInput = modifier((element: HTMLInputElement) => {
    this.#input = element;
    return () => (this.#input = undefined);
  });
  /**
   * The live input element. Read directly at submit time instead of mirroring
   * keystrokes into tracked state: the value only matters at that moment, and
   * clearing must reach the element's property — resetting a bound attribute
   * would not clear what the user typed.
   */
  #input?: HTMLInputElement;

  @action
  onKeydown(event: KeyboardEvent) {
    if (event.key === "Enter") {
      event.preventDefault();
      this.#submit();
    }
  }

  @action
  submit() {
    this.#submit();
  }

  #submit() {
    const element = this.#input;
    const value = element?.value.trim();
    if (!element || !value) {
      return;
    }
    this.args.onCreate?.(value);
    element.value = "";
  }

  <template>
    {{#let (dElement @itemTag) as |Wrapper|}}
      <Wrapper class="d-reorderable-list__create">
        <input
          {{this.captureInput}}
          {{on "keydown" this.onKeydown}}
          type="text"
          class="d-reorderable-list__create-input"
          aria-label={{i18n "reorder.add_item"}}
        />
        <DButton
          @icon="plus"
          @action={{this.submit}}
          @translatedAriaLabel={{i18n "reorder.add_item"}}
          @translatedTitle={{i18n "reorder.add_item"}}
          class="btn-flat d-reorderable-list__create-button"
        />
      </Wrapper>
    {{/let}}
  </template>
}

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
   * Applied by the arrow pair wherever it renders, so the component knows the
   * row kept its keyboard path regardless of where a manual placement put it.
   */
  registerKeyboardPath = modifier((_element: Element, [key]: [string]) => {
    this.#keyboardPathKeys.add(key);
    return () => this.#keyboardPathKeys.delete(key);
  });
  /**
   * Guards the manual-placement contract: a movable row under
   * `@controls="manual"` must place the yielded arrows (alone or fused), or
   * it silently loses its keyboard path. Checked after render, once the row's
   * descendants have registered.
   */
  verifyKeyboardPath = modifier((element: Element) => {
    // The key is read from the element rather than taken as an argument: an
    // argument's tracking tag invalidates on every rows recompute, and a
    // function modifier that consumed it would tear down and re-run each
    // time. Reading only the element keeps this a strict once-per-element
    // lifecycle hook.
    if (!this.isManual) {
      return;
    }
    const key = element.getAttribute("data-reorderable-key") ?? "";
    schedule("afterRender", () => {
      if (isDestroying(this) || isDestroyed(this)) {
        return;
      }
      assert(
        `d-reorderable-list: the manual row "${key}" renders no keyboard path — place the yielded arrows or controls`,
        this.#keyboardPathKeys.has(key)
      );
    });
  });
  /**
   * Clears the in-flight drag key when the dragged row is destroyed: a source
   * torn down mid-drag may never report its `dragend`, and the stale key
   * would otherwise mark a later row for the same item as still dragging.
   * Deferred a tick because the teardown runs inside a render pass that has
   * already read the key.
   */
  trackRowDragState = modifier((element: Element) => {
    // The key is read from the element for the same reason as in
    // `verifyKeyboardPath`: consuming a reactive argument would re-run this
    // modifier on every rows recompute, and its cleanup would then wrongly
    // clear a drag that is still in flight.
    const key = element.getAttribute("data-reorderable-key") ?? "";
    return () => {
      if (this._draggingKey !== key) {
        return;
      }
      next(() => {
        if (
          !isDestroying(this) &&
          !isDestroyed(this) &&
          this._draggingKey === key
        ) {
          this._draggingKey = null;
        }
      });
    };
  });
  /** The keys whose arrow pair is currently rendered, for the manual guard. */
  #keyboardPathKeys = new Set<string>();

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

  get controlsPlacement(): "start" | "end" | "manual" {
    return this.args.controls ?? "start";
  }

  get isManual(): boolean {
    return this.controlsPlacement === "manual";
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
      const rowMovable = !disabled && (movable ? movable(item) : true);
      return {
        item,
        key,
        index,
        movable: rowMovable,
        isFirst: false,
        isLast: false,
        isDragging: key === this._draggingKey,
        disableUp: false,
        disableDown: false,
        handleLabel: i18n("reorder.drag_handle", { label: itemLabel }),
        upLabel: i18n("reorder.move_up", { label: itemLabel }),
        downLabel: i18n("reorder.move_down", { label: itemLabel }),
        yieldControls: rowMovable && this.isManual,
      };
    });

    const movableRows = rows.filter((row) => row.movable);
    // With a single movable item every direction is a no-op, so both arrows
    // are marked unavailable even under `@wrap` — wrapping a list of one
    // would otherwise leave enabled-looking controls that never do anything.
    const alone = movableRows.length < 2;
    for (const [seqIndex, row] of movableRows.entries()) {
      row.isFirst = seqIndex === 0;
      row.isLast = seqIndex === movableRows.length - 1;
      row.disableUp = alone || (!wrap && row.isFirst);
      row.disableDown = alone || (!wrap && row.isLast);
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
                  {{this.verifyKeyboardPath}}
                  {{this.trackRowDragState}}
                >
                  {{#if (eq this.controlsPlacement "start")}}
                    <ReorderControls
                      @row={{row}}
                      @dragType={{this.dragType}}
                      @arrowsLayout={{@arrowsLayout}}
                      @onDragStart={{this.onSourceDragStart}}
                      @onDragEnd={{this.onSourceDragEnd}}
                      @moveRow={{this.moveRow}}
                      @register={{this.registerKeyboardPath}}
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
                      handle=(if
                        row.yieldControls
                        (component
                          HandlePart
                          row=row
                          dragType=this.dragType
                          onDragStart=this.onSourceDragStart
                          onDragEnd=this.onSourceDragEnd
                        )
                      )
                      arrows=(if
                        row.yieldControls
                        (component
                          ArrowsPart
                          row=row
                          arrowsLayout=@arrowsLayout
                          moveRow=this.moveRow
                          register=this.registerKeyboardPath
                        )
                      )
                      controls=(if
                        row.yieldControls
                        (component
                          ReorderControls
                          row=row
                          dragType=this.dragType
                          arrowsLayout=@arrowsLayout
                          onDragStart=this.onSourceDragStart
                          onDragEnd=this.onSourceDragEnd
                          moveRow=this.moveRow
                          register=this.registerKeyboardPath
                        )
                      )
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
                      @register={{this.registerKeyboardPath}}
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
        {{#if @allowCreate}}
          {{#if (has-block "create")}}
            {{yield to="create"}}
          {{else}}
            <CreateRow @itemTag={{this.itemTag}} @onCreate={{@onCreate}} />
          {{/if}}
        {{/if}}
        {{yield to="static"}}
      </List>
    {{/let}}
  </template>
}
