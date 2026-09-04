import { isDestroying, registerDestructor } from "@ember/destroyable";
import { cancel, type Timer } from "@ember/runloop";
import discourseLater from "discourse/lib/later";
import type A11yService from "discourse/services/a11y";
import { RUN_SETTLE_MS } from "discourse/ui-kit/d-reorderable-list/-internals/constants";
import type {
  MoveTarget,
  ReorderableMove,
  Row,
} from "discourse/ui-kit/d-reorderable-list/types";
import { i18n } from "discourse-i18n";

/** The arguments the announcements read, resolved per call rather than captured. */
interface AnnouncerArgs<T> {
  label: (item: T) => string;
  announceMove?: (move: ReorderableMove<T>) => string | false;
  listLabel?: string;
}

interface ReorderAnnouncerOptions<T> {
  a11y: A11yService;

  /** The list's current arguments; never a snapshot. */
  getArgs: () => AnnouncerArgs<T>;

  /** The list's current row projection, read only when a run settles. */
  rows: () => Row<T>[];
}

/**
 * Everything a reorderable list says out loud. Owns the chord-run state and
 * therefore its timer, cancelled from its own destructor — which requires the
 * component to call `associateDestroyableChild`, or nothing here is ever
 * destroyed and `isDestroying` stays false forever.
 */
export default class ReorderAnnouncer<T> {
  #a11y: A11yService;
  #getArgs: () => AnnouncerArgs<T>;
  #rows: () => Row<T>[];

  /**
   * The run of consecutive chord moves in flight, if any. A held Alt+arrow
   * would otherwise speak a full sentence per step into a live region that
   * re-announces even an unchanged string, so a run says only where the row
   * now is and the full sentence waits for the run to settle.
   */
  #run: {
    index: number;
    move?: ReorderableMove<T>;
    timer: Timer;
  } | null = null;

  constructor({ a11y, getArgs, rows }: ReorderAnnouncerOptions<T>) {
    this.#a11y = a11y;
    this.#getArgs = getArgs;
    this.#rows = rows;
    registerDestructor(this, () => this.cancelRun());
  }

  /**
   * Speaks one committed move, honoring the `@announceMove` override and the
   * cross-list variant. Reached only after the move's callback owner declined
   * to veto it — the gate lives with the dispatch, not here.
   *
   * @param move - The normalized move to speak.
   */
  announceMove(move: ReorderableMove<T>) {
    const args = this.#getArgs();

    if (args.announceMove) {
      const custom = args.announceMove(move);
      if (custom !== false) {
        this.#a11y.announce(custom);
      }
      return;
    }

    const label = args.label(move.item);
    const position = move.toIndex + 1;
    const total = move.proposedToItems.length;

    // Mid-run, position only; the full sentence lands when the run settles.
    if (this.#run) {
      this.#a11y.announce(i18n("reorder.position", { position, total }));
      return;
    }

    if (move.fromList !== move.toList && args.listLabel) {
      this.#a11y.announce(
        i18n("reorder.announcement_cross_list", {
          label,
          list: args.listLabel,
          position,
          total,
        })
      );
      return;
    }

    this.#announceMoved(move.item, move.toIndex, total);
  }

  /**
   * Marks a chord move as part of a run. A menu move is always deliberate and
   * single, so it ends any run rather than joining one.
   *
   * @param key - The row being moved.
   * @param method - Which input method asked.
   */
  noteRun(key: string, method: "menu" | "keyboard") {
    this.cancelRun();
    if (method !== "keyboard") {
      return;
    }
    // A custom announcer owns its full message and throttling for every move.
    if (this.#getArgs().announceMove) {
      return;
    }
    const index = this.#rows().find((row) => row.key === key)?.index;
    if (index === undefined) {
      return;
    }
    this.#run = {
      index,
      timer: discourseLater(() => {
        if (isDestroying(this)) {
          return;
        }
        const run = this.#run;
        this.#run = null;
        const rows = this.#rows();
        const row = run ? rows[run.index] : undefined;
        if (row && run?.move && Object.is(row.item, run.move.item)) {
          // Counted from the list as it stands, not from the order the move was
          // committed against, which the settle delay may have left behind.
          this.announceMove({
            ...run.move,
            item: row.item,
            toIndex: row.index,
            proposedToItems: rows.map((candidate) => candidate.item),
          });
        }
      }, RUN_SETTLE_MS),
    };
  }

  /** Points the armed chord run at the row's committed landing slot. */
  updateRun(move: ReorderableMove<T>) {
    if (this.#run) {
      this.#run.index = move.toIndex;
      this.#run.move = move;
    }
  }

  /** Ends an armed chord run without speaking for it. */
  cancelRun() {
    if (this.#run) {
      cancel(this.#run.timer);
      this.#run = null;
    }
  }

  /**
   * Speaks a refused move at either end of the list. The refusal is
   * information rather than an error: it is how a reader learns they have
   * arrived, which a silent no-op never tells them.
   *
   * Deliberately does not end an in-flight run: a chord that walks into the
   * boundary still settles into its full sentence afterwards.
   *
   * @param row - The row that could not move.
   * @param target - The direction that was refused.
   */
  announceBoundary(row: Row<T>, target: MoveTarget) {
    // Built from the direction, so neither key appears as a literal anywhere.
    // `reorder.at_start` and `reorder.at_end` are live; a grep will not say so.
    const key = target === "up" || target === "top" ? "at_start" : "at_end";
    this.#a11y.announce(
      i18n(`reorder.${key}`, { label: this.#getArgs().label(row.item) })
    );
  }

  /** Speaks when an explicit destination disappeared or refused the move. */
  announceRefusal(row: Row<T>) {
    this.#a11y.announce(
      i18n("reorder.move_refused", {
        label: this.#getArgs().label(row.item),
      })
    );
  }

  /**
   * Speaks a committed move in the standard form.
   *
   * @param item - The item that moved.
   * @param index - Its visible index afterwards.
   * @param total - The visible list length afterwards.
   */
  #announceMoved(item: T, index: number, total: number) {
    this.#a11y.announce(
      i18n("reorder.announcement", {
        label: this.#getArgs().label(item),
        position: index + 1,
        total,
      })
    );
  }
}
