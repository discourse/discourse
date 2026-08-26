import type ReorderAnnouncer from "discourse/ui-kit/d-reorderable-list/-internals/coordinators/reorder-announcer";
import type {
  MoveTarget,
  ReorderableGroupApi,
  ReorderableMove,
  Row,
} from "discourse/ui-kit/d-reorderable-list/types";

/** The arguments a move reads, resolved per call rather than captured. */
interface MoveEngineArgs<T> {
  items: readonly T[];
  group?: ReorderableGroupApi;
  onMove?: (move: ReorderableMove<T>) => void | false;
  listLabel?: string;
}

interface MoveEngineOptions<T> {
  /** The list's current arguments; never a snapshot. */
  args: () => MoveEngineArgs<T>;

  /** The list's current row projection, resolved at commit time. */
  rows: () => Row<T>[];

  /** The list's group id, or its standalone default. */
  listId: () => string;

  /** What speaks the result. */
  announcer: ReorderAnnouncer<T>;

  /**
   * Returns focus to a row's handle after a commit moved it in the DOM.
   *
   * Owned by the component rather than here, because it resolves against the
   * list element the keyboard modifier installed on. An engine holding that
   * element instead would have captured `null` at construction and fallen back
   * to a document-wide query, which lands on the wrong list as soon as two
   * index-keyed members share a key.
   */
  refocusIndex: (index: number) => void;
}

/**
 * The move algebra: every committed reorder, in-list and cross-list alike.
 *
 * Owns the single commit chokepoint. Both input methods and both drag paths
 * funnel into `commitSeqMove`, which calls the consumer back once and
 * announces once, and neither for a move that lands where it started.
 */
export default class MoveEngine<T> {
  #args: () => MoveEngineArgs<T>;
  #rows: () => Row<T>[];
  #listId: () => string;
  #announcer: ReorderAnnouncer<T>;
  #refocusIndex: (index: number) => void;

  constructor({
    args,
    rows,
    listId,
    announcer,
    refocusIndex,
  }: MoveEngineOptions<T>) {
    this.#args = args;
    this.#rows = rows;
    this.#listId = listId;
    this.#announcer = announcer;
    this.#refocusIndex = refocusIndex;
  }

  /**
   * The in-list move both the menu and the chord funnel into: one step or one
   * jump within the movable subsequence, then focus back onto the handle the
   * move just displaced.
   *
   * Resolved fresh by key rather than acting on the row object the render
   * captured, because a move commits against the list as it stands now.
   *
   * A move that would leave the list past either end is refused, and the
   * refusal is announced. Reaching an end is information, and a silent no-op is
   * the failure this component exists to stop repeating. Only the accelerator
   * arrives here at a boundary, the menu having omitted that destination
   * entirely, which is what makes the spoken refusal the only account of it.
   *
   * @param key - The row to move.
   * @param target - Where to move it.
   * @param method - Which input method asked.
   */
  move(key: string, target: MoveTarget, method: "menu" | "keyboard") {
    const rows = this.#rows();
    const row = rows.find((candidate) => candidate.key === key);
    if (!row?.movable) {
      return;
    }

    const seq = rows.filter((candidate) => candidate.movable);
    const from = seq.indexOf(row);
    const to = {
      up: from - 1,
      down: from + 1,
      top: 0,
      bottom: seq.length - 1,
    }[target];

    if (to < 0 || to >= seq.length || to === from) {
      this.#announcer.announceBoundary(row, target);
      return;
    }

    this.#announcer.noteRun(key, method);
    const committed = this.commitSeqMove(method, rows, seq, from, to);
    // Addressed by where the row landed, not by the key it had. On a list keyed
    // by position that key now belongs to whichever row took the vacated slot,
    // so refocusing by it hands the next press a different row and the two
    // trade places for as long as the reader holds the chord.
    if (committed) {
      this.#refocusIndex(committed.toIndex);
    }
  }

  /**
   * The single commit both input methods funnel into: splices the move within
   * the movable subsequence, re-interleaves it with the frozen rows (which
   * keep their exact visible indices), suppresses no-ops, calls `@onMove`
   * once, and announces once. Returns the committed move, or `null` for a
   * no-op, so a caller can address the row by where it landed.
   *
   * @param method - Which input method asked for the move.
   * @param rows - The current row projection.
   * @param seq - The movable rows, in visible order.
   * @param from - The item's index within `seq`.
   * @param to - The destination index within `seq`.
   */
  commitSeqMove(
    method: ReorderableMove<T>["method"],
    rows: Row<T>[],
    seq: Row<T>[],
    from: number,
    to: number
  ): ReorderableMove<T> | null {
    const move = this.#buildSeqMove(method, rows, seq, from, to);
    if (move) {
      this.#finalize(move);
    }
    return move;
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

    const { items } = this.#args();
    const listId = this.#listId();
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
   * @param method - Which input method asked for the move.
   */
  commitCrossMove(
    sourceListId: string | undefined,
    key: string,
    toIndex: number,
    method: ReorderableMove<T>["method"]
  ) {
    const { group } = this.#args();
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
    const rows = this.#rows();
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
      method,
      item,
      fromList: sourceListId,
      toList: this.#listId(),
      fromIndex: removal.fromIndex,
      toIndex: proposedTo.indexOf(item),
      fromItems: member.getItems() as readonly T[],
      toItems: this.#args().items,
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
    this.#announcer.announceMove(move);
  }

  /**
   * Reports a move to its callback owner — the group when the list is a
   * member, its own `@onMove` otherwise.
   *
   * @param move - The normalized move.
   * @returns Whether the move may be announced (`false` when vetoed).
   */
  #dispatch(move: ReorderableMove<T>): boolean {
    const handler = this.#args().group?.onMove ?? this.#args().onMove;
    return handler?.(move) !== false;
  }

  /**
   * What this list would look like with one row taken out of it, handed to the
   * group so a destination member can resolve a cross-list drop against the
   * source as it stands at drop time rather than a snapshot.
   *
   * @param key - The row leaving this list.
   * @returns The projection, or `undefined` when the row cannot leave.
   */
  removalProjection(key: string) {
    const rows = this.#rows();
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
  }
}
