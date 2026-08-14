import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import type { TOC } from "@ember/component/template-only";
import { assert } from "@ember/debug";
import {
  isDestroyed,
  isDestroying,
  registerDestructor,
} from "@ember/destroyable";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, get } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import type Owner from "@ember/owner";
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
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dDragAndDropSource, {
  DragSource,
} from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dDragAndDropTarget, {
  DropTargetEvent,
  registerDragAndDropTarget,
} from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import dRovingFocus from "discourse/ui-kit/modifiers/d-roving-focus";
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
 * What a member list registers with its group: identity, the optional
 * translated list name for cross-list announcements, and closures reading the
 * member's live state — closures rather than snapshots, so a drop resolves
 * against the source list as it stands at drop time.
 */
export interface ReorderableGroupMember {
  listId: string;
  listLabel?: string;

  /** The member's current visible items. */
  getItems: () => readonly unknown[];

  /**
   * The source half of a cross-list move: resolves the dragged key against
   * the member's current rows and returns the item, its visible index, and
   * the member's proposed order without it — or `undefined` when the key no
   * longer resolves to a movable row.
   */
  removalProjection: (key: string) =>
    | {
        item: unknown;
        fromIndex: number;
        proposedFromItems: readonly unknown[];
      }
    | undefined;
}

/**
 * The API a `DReorderableListGroup` yields to its block. Member lists receive
 * it as `@group`; everything on it is wiring between the group and its
 * members rather than a consumer surface.
 */
export interface ReorderableGroupApi {
  /**
   * The shared drag discriminator. Members adopt it in place of their own, so
   * drags travel freely inside the group and nowhere else.
   */
  token: string;

  /** Adds a member; returns its deregistration. Duplicate listIds assert. */
  registerMember: (member: ReorderableGroupMember) => () => void;

  /** The member registered under a listId, if it still exists. */
  lookupMember: (listId: string) => ReorderableGroupMember | undefined;

  /** The group's single move callback, shared by every member. */
  onMove: (move: ReorderableMove) => void | false;
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
  isGrabbed: boolean;
  grabLabel: string;
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
     * Required for a standalone list; a grouped member omits it — the group's
     * own callback receives every member move instead.
     */
    onMove?: (move: ReorderableMove<T>) => void | false;

    /**
     * The API yielded by a surrounding `DReorderableListGroup`. Joining a
     * group makes cross-list drags between members possible and routes every
     * move through the group's callback. Requires `@listId`. Fixed at
     * construction: a list that must change groups is re-created, not
     * re-pointed. Cross-list movement is pointer-only — the arrows stay
     * within their own list, matching the shipped behavior of the surfaces
     * this component standardizes.
     */
    group?: ReorderableGroupApi;

    /**
     * This member's identity inside its group. Required with `@group`, and
     * fixed at construction like the group itself.
     */
    listId?: string;

    /**
     * Translated name for this list, spoken in cross-list announcements when
     * an item lands here from another member. Without it the standard
     * announcement is used.
     */
    listLabel?: string;

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
     * The keyboard interaction model. The default `"buttons"` renders the
     * arrow pair on every movable row — simple and discoverable, at the cost
     * of two tab stops per row. `"grab"` renders one grab button per row and
     * makes the whole list a single tab stop: arrow keys move focus between
     * rows, Space or Enter grabs, arrows then move the grabbed row, Space
     * drops, and Escape returns it to where it was picked up.
     *
     * Grab mode requires stable item identity and assumes the list is not
     * nested inside another grab-mode list — the roving cursor matches grab
     * buttons among its descendants.
     */
    keyboard?: "buttons" | "grab";

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
     * button by default, or the `<:create>` block when one is given. The
     * default row is list-shaped (it renders as one extra item element), so a
     * table shell should supply its own `<:create>` block with valid cell
     * markup.
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
    sourceListId: string;
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
      data=(hash key=@row.key listId=@sourceListId)
      onDragStart=@onDragStart
      onDragEnd=@onDragEnd
    }}
    @label={{@row.handleLabel}}
    class="d-reorderable-list__handle"
    ...attributes
  />
</template>;

interface GrabHandlePartSignature {
  Args: {
    row: Row<unknown>;
    dragType: string;
    sourceListId: string;
    instructionsId: string;
    onDragStart: (event: { source: DragSource }) => void;
    onDragEnd: () => void;
    onToggle: (event: MouseEvent) => void;
  };
  Element: HTMLButtonElement;
}

/**
 * The grab-mode control: one real button per movable row, serving both input
 * channels — pointer users drag it, keyboard users press Space on it. Its
 * grabbed state is spoken through `aria-pressed`, and the shared instructions
 * element it references teaches the key vocabulary.
 */
const GrabHandlePart: TOC<GrabHandlePartSignature> = <template>
  <button
    {{dDragAndDropSource
      type=@dragType
      data=(hash key=@row.key listId=@sourceListId)
      onDragStart=@onDragStart
      onDragEnd=@onDragEnd
    }}
    {{on "click" @onToggle}}
    type="button"
    class="d-reorderable-list__handle --grab btn-flat"
    aria-label={{@row.grabLabel}}
    aria-pressed={{if @row.isGrabbed "true" "false"}}
    aria-describedby={{@instructionsId}}
    title={{@row.grabLabel}}
    ...attributes
  >{{dIcon "grip-vertical"}}</button>
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
    sourceListId: string;
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
    @sourceListId={{@sourceListId}}
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
    // A keydown arriving mid-IME-composition belongs to the candidate window,
    // not to this control.
    if (event.key === "Enter" && !event.isComposing) {
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
    // Without a handler the value has nowhere to go, so it stays in the input
    // instead of being silently discarded.
    if (!element || !value || !this.args.onCreate) {
      return;
    }
    this.args.onCreate(value);
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
   * it silently loses its keyboard path. Checked once per row element, after
   * its first render — a consumer that conditionally removes its placed
   * arrows later is beyond this guard's reach.
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
  /**
   * Registers the list's root element as a drop target while the list is an
   * empty group member — the one state with no rows to land on. Applied
   * statically and registered imperatively: a conditionally curried modifier
   * breaks on the classic-component element wrapper the shell falls back to
   * for non-shortcut tags. Deliberately consumes `acceptsRootDrops`, so it
   * re-registers exactly when the items or group change — never mid-drag.
   */
  rootDropTarget = modifier((element: Element) => {
    if (!this.acceptsRootDrops) {
      return;
    }
    return registerDragAndDropTarget(element, () => ({
      accepts: this.dragType,
      position: "inside" as const,
      onDrop: this.onEmptyRootDrop,
    }));
  });

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
  /**
   * Intercepts the movement keys while a row is grabbed, ahead of the roving
   * cursor's own listener: a grabbed arrow press moves the row, not the
   * focus. Consumes nothing reactive — the grabbed key is read at event time.
   */
  grabKeys = modifier((element: Element) => {
    this.#listElement = element;
    const handler = (event: Event) => {
      const { key, target } = event as KeyboardEvent;
      if (
        !this.isGrab ||
        !this._grabbedKey ||
        !(target instanceof Element) ||
        !target.closest(".d-reorderable-list__handle.--grab")
      ) {
        return;
      }
      if (key === "ArrowDown" || key === "ArrowUp") {
        event.preventDefault();
        event.stopPropagation();
        this.moveRow(this._grabbedKey, key === "ArrowDown" ? "down" : "up");
        this.#refocusGrabbed();
      } else if (key === "Escape") {
        event.preventDefault();
        event.stopPropagation();
        this.#cancelGrab();
      }
    };
    element.addEventListener("keydown", handler, { capture: true });
    return () => {
      element.removeEventListener("keydown", handler, { capture: true });
      this.#listElement = null;
    };
  });

  /** The list's root element, held for grab-mode focus restoration. */
  #listElement: Element | null = null;
  /** The private drag discriminator used when the list stands alone. */
  #ownDragType = `d-reorderable-list:${guidFor(this)}`;

  /** The keys whose arrow pair is currently rendered, for the manual guard. */
  #keyboardPathKeys = new Set<string>();

  /** The grabbed row's visible index at grab time, for Escape to restore. */
  #grabOriginIndex: number | null = null;
  /**
   * The key of the row whose drag is in flight, so every row can yield its
   * own `isDragging`. Keyed rather than held as an element or item reference,
   * because the host may replace its items mid-drag.
   */
  @tracked _draggingKey: string | null = null;

  /** The key of the row currently held by the grab keyboard mode. */
  @tracked _grabbedKey: string | null = null;

  constructor(owner: Owner, args: DReorderableListSignature<T>["Args"]) {
    super(owner, args);

    const { group } = this.args;
    if (group && !this.args.listId) {
      // Reported after render rather than thrown here: an exception unwinding
      // a half-built render corrupts it. The list simply stays unregistered.
      schedule("afterRender", () => {
        if (isDestroying(this) || isDestroyed(this)) {
          return;
        }
        assert(
          "d-reorderable-list: @listId is required when the list joins a group",
          false
        );
      });
    } else if (group) {
      const unregister = group.registerMember({
        listId: this.args.listId!,
        listLabel: this.args.listLabel,
        getItems: () => this.args.items,
        removalProjection: (key: string) => {
          const rows = this.rows;
          const moved = rows.find((candidate) => candidate.key === key);
          if (!moved?.movable) {
            return undefined;
          }
          // The same slot model as an in-list move: frozen rows keep their
          // exact visible indices while the remaining movable items refill
          // the movable slots in order, and the list shrinks by its last
          // slot. A frozen row that sat on the dropped final slot has no
          // index to keep and joins the end of the refill queue.
          const size = rows.length - 1;
          const empty = Symbol("empty");
          const proposed: (T | typeof empty)[] = new Array(size).fill(empty);
          const overflow: T[] = [];
          for (const row of rows) {
            if (!row.movable) {
              if (row.index < size) {
                proposed[row.index] = row.item;
              } else {
                overflow.push(row.item);
              }
            }
          }
          const queue = rows
            .filter((row) => row.movable && row.key !== key)
            .map((row) => row.item)
            .concat(overflow);
          let cursor = 0;
          for (let index = 0; index < size; index++) {
            if (proposed[index] === empty) {
              proposed[index] = queue[cursor++]!;
            }
          }
          return {
            item: moved.item,
            fromIndex: moved.index,
            proposedFromItems: proposed as readonly T[],
          };
        },
      });
      registerDestructor(this, unregister);
    }
  }

  /**
   * The drag discriminator in force: the group's shared token when the list
   * is a member — which is what lets drags travel between members — and a
   * private per-instance one otherwise, so unrelated lists on one page can
   * never accept each other's drags.
   */
  get dragType(): string {
    return this.args.group?.token ?? this.#ownDragType;
  }

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

  get isGrab(): boolean {
    return this.args.keyboard === "grab";
  }

  /** The id linking every grab button to the shared instructions element. */
  get instructionsId(): string {
    return `${guidFor(this)}-grab-instructions`;
  }

  /** This list's move-payload identity: its group listId, or `"default"`. */
  get listIdOrDefault(): string {
    return this.args.listId ?? "default";
  }

  /**
   * Whether the list's root element accepts drops: only as an empty group
   * member, where there are no rows to land on. Reads `@items` directly
   * rather than `rows`, so the conditional target below re-curries only when
   * the items themselves change — never on drag-state churn.
   */
  get acceptsRootDrops(): boolean {
    return (
      !!this.args.group && this.args.items.length === 0 && !this.args.disabled
    );
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
        isGrabbed: key === this._grabbedKey,
        grabLabel: i18n("reorder.grab_handle", { label: itemLabel }),
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

  /**
   * The grab toggle, invoked by the roving cursor's activation keys on a grab
   * button. First press grabs and announces the held position; second press
   * drops and announces the final one.
   *
   * @param element - The activated grab button.
   */
  /**
   * Pointer (and assistive-technology synthesized) activation of a grab
   * button. Keyboard activation arrives through the roving cursor instead,
   * whose prevented keydown suppresses the browser's synthetic click, so the
   * two paths never double-toggle.
   *
   * @param event - The click event.
   */
  @action
  onGrabClick(event: MouseEvent) {
    if (event.currentTarget instanceof HTMLElement) {
      this.onGrabActivate(event.currentTarget);
    }
  }

  @action
  onGrabActivate(element: HTMLElement) {
    // Index identity cannot hold a grab: the key names a position, so after
    // one step it would name a different item. Stable identity is a
    // precondition of the grab mode.
    assert(
      'd-reorderable-list: the grab keyboard mode requires stable item identity — do not combine it with @key="@index"',
      this.args.key !== "@index"
    );
    const key = element
      .closest("[data-reorderable-key]")
      ?.getAttribute("data-reorderable-key");
    const row = this.rows.find((candidate) => candidate.key === key);
    if (!row?.movable) {
      return;
    }

    if (this._grabbedKey === row.key) {
      this._grabbedKey = null;
      this.#grabOriginIndex = null;
      this.a11y.announce(
        i18n("reorder.dropped", {
          label: this.args.label(row.item),
          position: row.index + 1,
          total: this.rows.length,
        })
      );
      return;
    }

    this._grabbedKey = row.key;
    this.#grabOriginIndex = row.index;
    this.a11y.announce(
      i18n("reorder.grabbed", {
        label: this.args.label(row.item),
        position: row.index + 1,
        total: this.rows.length,
      })
    );
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
    const targetRow = rows.find((candidate) => candidate.key === targetKey);
    if (!targetRow?.movable) {
      return;
    }

    const sourceListId = source.data.listId as string | undefined;
    if (this.args.group && sourceListId !== this.listIdOrDefault) {
      const toIndex = targetRow.index + (position === "after" ? 1 : 0);
      this.#commitCrossMove(sourceListId, source.data.key as string, toIndex);
      return;
    }

    const sourceRow = rows.find(
      (candidate) => candidate.key === source.data.key
    );
    if (!sourceRow?.movable) {
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

  /**
   * The drop path for the list's own root element, registered only while the
   * list is an empty group member — the one state with no rows to land on.
   *
   * @param event - The target modifier's drop payload.
   */
  @action
  onEmptyRootDrop({ source }: DropTargetEvent) {
    if (!this.acceptsRootDrops || this.rows.length > 0) {
      return;
    }
    this.#commitCrossMove(
      source.data.listId as string | undefined,
      source.data.key as string,
      0
    );
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
    const move = this.#buildSeqMove(method, rows, seq, from, to);
    if (move) {
      this.#finalize(move);
    }
  }

  /**
   * Builds the normalized move for one step within the movable subsequence,
   * or `null` for a no-op.
   *
   * @param method - Which input method asked for the move.
   * @param rows - The current row projection.
   * @param seq - The movable rows, in visible order.
   * @param from - The item's index within `seq`.
   * @param to - The destination index within `seq`.
   */
  #buildSeqMove(
    method: ReorderableMove<T>["method"],
    rows: Row<T>[],
    seq: Row<T>[],
    from: number,
    to: number
  ): ReorderableMove<T> | null {
    if (to === from) {
      return null;
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
    const listId = this.listIdOrDefault;
    return {
      method,
      item: moved.item,
      fromList: listId,
      toList: listId,
      fromIndex: moved.index,
      toIndex,
      fromItems: items,
      toItems: items,
      proposedFromItems: proposed,
      proposedToItems: proposed,
    };
  }

  /**
   * The destination half of a cross-list move: resolves the source member
   * through the group, asks it for its removal projection, splices the item
   * into this list's visible order, and finalizes. A source member that
   * unregistered mid-drag, or a key that no longer resolves there, refuses
   * the drop silently.
   *
   * @param sourceListId - The group listId the payload named as its origin.
   * @param key - The dragged row's key in the source member.
   * @param toIndex - The visible landing index in this list.
   */
  #commitCrossMove(
    sourceListId: string | undefined,
    key: string,
    toIndex: number
  ) {
    const { group } = this.args;
    if (!group || !sourceListId) {
      return;
    }
    const member = group.lookupMember(sourceListId);
    const removal = member?.removalProjection(key);
    if (!member || !removal) {
      return;
    }

    // The same slot model as everywhere else: frozen destination rows keep
    // their exact visible indices while the list grows by one slot, and the
    // arriving item joins the movable subsequence at the requested position.
    const rows = this.rows;
    const item = removal.item as T;
    const size = rows.length + 1;
    const empty = Symbol("empty");
    const proposedTo: (T | typeof empty)[] = new Array(size).fill(empty);
    for (const row of rows) {
      if (!row.movable) {
        proposedTo[row.index] = row.item;
      }
    }
    const seqInsert = rows.filter(
      (row) => row.movable && row.index < toIndex
    ).length;
    const queue = rows.filter((row) => row.movable).map((row) => row.item);
    queue.splice(seqInsert, 0, item);
    let cursor = 0;
    for (let index = 0; index < size; index++) {
      if (proposedTo[index] === empty) {
        proposedTo[index] = queue[cursor++]!;
      }
    }

    this.#finalize({
      method: "drag",
      item,
      fromList: sourceListId,
      toList: this.listIdOrDefault,
      fromIndex: removal.fromIndex,
      toIndex: proposedTo.indexOf(item),
      fromItems: member.getItems() as readonly T[],
      toItems: this.args.items,
      proposedFromItems: removal.proposedFromItems as readonly T[],
      proposedToItems: proposedTo as readonly T[],
    });
  }

  /**
   * The single exit for every committed move: routes the callback to the
   * group when the list is a member (its own `@onMove` otherwise), honors the
   * veto and the `@announceMove` override, and speaks exactly one
   * announcement — the cross-list variant when an item landed here from
   * another member and this list carries a `@listLabel`.
   *
   * @param move - The normalized move to report.
   */
  #finalize(move: ReorderableMove<T>) {
    if (!this.#dispatch(move)) {
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
      const label = this.args.label(move.item);
      const position = move.toIndex + 1;
      const total = move.proposedToItems.length;
      if (move.fromList !== move.toList && this.args.listLabel) {
        message = i18n("reorder_announcement_cross_list", {
          label,
          list: this.args.listLabel,
          position,
          total,
        });
      } else {
        message = i18n("reorder_announcement", { label, position, total });
      }
    }

    this.a11y.announce(message);
  }

  /**
   * Reports a move to its callback owner — the group when the list is a
   * member, its own `@onMove` otherwise.
   *
   * @param move - The normalized move.
   * @returns Whether the move may be announced (`false` when vetoed).
   */
  #dispatch(move: ReorderableMove<T>): boolean {
    const handler = this.args.group?.onMove ?? this.args.onMove;
    return handler?.(move) !== false;
  }

  /**
   * Escape while grabbed: one restoring commit back to the grab-start index
   * when the row has moved (reported but not given the standard step
   * announcement — the cancellation is the announcement), then the cleared
   * state.
   */
  #cancelGrab() {
    const key = this._grabbedKey;
    const origin = this.#grabOriginIndex;
    this._grabbedKey = null;
    this.#grabOriginIndex = null;

    const rows = this.rows;
    const row = rows.find((candidate) => candidate.key === key);
    if (!row?.movable || origin == null) {
      return;
    }

    if (row.index !== origin) {
      const seq = rows.filter((candidate) => candidate.movable);
      const movableSlots = seq.map((candidate) => candidate.index);
      const from = seq.indexOf(row);
      const to = movableSlots.indexOf(origin);
      // The origin slot can vanish while grabbed (the host mutated its items);
      // the cancellation then simply leaves the row where it stands.
      if (to >= 0) {
        const move = this.#buildSeqMove("buttons", rows, seq, from, to);
        if (move) {
          this.#dispatch(move);
        }
      }
    }

    this.a11y.announce(
      i18n("reorder.cancelled", {
        label: this.args.label(row.item),
        position: origin + 1,
      })
    );
    this.#refocusGrabbed(key);
  }

  /**
   * Takes focus back to a grab button after its row moved in the DOM, which
   * blurs it — the grab mode's counterpart of the arrow pair's own refocus.
   *
   * @param key - The row key to refocus; defaults to the grabbed row.
   */
  #refocusGrabbed(key: string | null = this._grabbedKey) {
    schedule("afterRender", () => {
      if (isDestroying(this) || isDestroyed(this) || !key) {
        return;
      }
      const root = this.#listElement ?? document;
      root
        .querySelector<HTMLElement>(
          `[data-reorderable-key="${CSS.escape(key)}"] .d-reorderable-list__handle.--grab`
        )
        ?.focus();
    });
  }

  <template>
    {{#let (dElement this.listTag) as |List|}}
      <List
        class={{dConcatClass
          "d-reorderable-list"
          (if this.revealControls "--reveal-controls")
        }}
        role={{@role}}
        {{this.rootDropTarget}}
        {{dRovingFocus
          itemSelector=".d-reorderable-list__handle.--grab"
          orientation="vertical"
          itemsKey=this.rows
          onActivate=this.onGrabActivate
        }}
        {{this.grabKeys}}
        ...attributes
      >
        {{#if this.isGrab}}
          <span id={{this.instructionsId}} class="sr-only">
            {{i18n "reorder.grab_instructions"}}
          </span>
        {{/if}}
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
                    (if row.isGrabbed "--grabbed")
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
                    {{#if this.isGrab}}
                      <GrabHandlePart
                        @row={{row}}
                        @dragType={{this.dragType}}
                        @sourceListId={{this.listIdOrDefault}}
                        @instructionsId={{this.instructionsId}}
                        @onDragStart={{this.onSourceDragStart}}
                        @onDragEnd={{this.onSourceDragEnd}}
                        @onToggle={{this.onGrabClick}}
                      />
                    {{else}}
                      <ReorderControls
                        @row={{row}}
                        @dragType={{this.dragType}}
                        @sourceListId={{this.listIdOrDefault}}
                        @arrowsLayout={{@arrowsLayout}}
                        @onDragStart={{this.onSourceDragStart}}
                        @onDragEnd={{this.onSourceDragEnd}}
                        @moveRow={{this.moveRow}}
                        @register={{this.registerKeyboardPath}}
                      />
                    {{/if}}
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
                          sourceListId=this.listIdOrDefault
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
                          sourceListId=this.listIdOrDefault
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
                    {{#if this.isGrab}}
                      <GrabHandlePart
                        @row={{row}}
                        @dragType={{this.dragType}}
                        @sourceListId={{this.listIdOrDefault}}
                        @instructionsId={{this.instructionsId}}
                        @onDragStart={{this.onSourceDragStart}}
                        @onDragEnd={{this.onSourceDragEnd}}
                        @onToggle={{this.onGrabClick}}
                      />
                    {{else}}
                      <ReorderControls
                        @row={{row}}
                        @dragType={{this.dragType}}
                        @sourceListId={{this.listIdOrDefault}}
                        @arrowsLayout={{@arrowsLayout}}
                        @onDragStart={{this.onSourceDragStart}}
                        @onDragEnd={{this.onSourceDragEnd}}
                        @moveRow={{this.moveRow}}
                        @register={{this.registerKeyboardPath}}
                      />
                    {{/if}}
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
