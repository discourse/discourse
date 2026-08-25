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

  /**
   * The list's current arguments. A thunk rather than a snapshot: a consumer
   * may swap `@label` or `@listLabel` at any time, and an announcement built
   * from a captured one would speak the wrong name for the rest of the
   * component's life.
   */
  getArgs: () => AnnouncerArgs<T>;

  /** The list's current row projection, read only when a run settles. */
  rows: () => Row<T>[];
}

/**
 * Everything a reorderable list says out loud.
 *
 * Owns the run state, which is why it owns the timer: a held chord speaks its
 * position only, and the full sentence lands once the key is released. The
 * timer must not outlive the list, so this cancels it from its own destructor
 * — which requires the component to call `associateDestroyableChild`, or
 * nothing here is ever destroyed and `isDestroying` stays false forever.
 */
export default class ReorderAnnouncer<T> {
  #a11y: A11yService;
  #getArgs: () => AnnouncerArgs<T>;
  #rows: () => Row<T>[];

  /**
   * The chord run in flight, if any. Untracked: nothing rendered reads it, and
   * it is written from a timer that fires after the render that scheduled it.
   */
  #run: { key: string; timer: Timer } | null = null;

  constructor({ a11y, getArgs, rows }: ReorderAnnouncerOptions<T>) {
    this.#a11y = a11y;
    this.#getArgs = getArgs;
    this.#rows = rows;
    registerDestructor(this, () => this.#cancelRun());
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

    // Mid-run, only where the row now is: the live region re-speaks even an
    // unchanged string, so a held key would otherwise read the same sentence
    // once per step. The full one lands when the run settles.
    if (this.#run) {
      this.#a11y.announce(i18n("reorder.position", { position, total }));
      return;
    }

    if (move.fromList !== move.toList && args.listLabel) {
      this.#a11y.announce(
        i18n("reorder_announcement_cross_list", {
          label,
          list: args.listLabel,
          position,
          total,
        })
      );
      return;
    }

    this.announceMoved(move.item, move.toIndex, total);
  }

  /**
   * Marks a chord move as part of a run, so a held key speaks position only
   * and the full sentence lands once the key is released. A menu move is
   * always deliberate and single, so it ends any run rather than joining one.
   *
   * @param key - The row being moved.
   * @param method - Which input method asked.
   */
  noteRun(key: string, method: "menu" | "keyboard") {
    this.#cancelRun();
    if (method !== "keyboard") {
      return;
    }
    this.#run = {
      key,
      timer: discourseLater(() => {
        if (isDestroying(this)) {
          return;
        }
        const run = this.#run;
        this.#run = null;
        const rows = this.#rows();
        const row = rows.find((candidate) => candidate.key === run?.key);
        if (row) {
          this.announceMoved(row.item, row.index, rows.length);
        }
      }, RUN_SETTLE_MS),
    };
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

  /**
   * Speaks a committed move in the standard form.
   *
   * @param item - The item that moved.
   * @param index - Its visible index afterwards.
   * @param total - The visible list length afterwards.
   */
  announceMoved(item: T, index: number, total: number) {
    this.#a11y.announce(
      i18n("reorder_announcement", {
        label: this.#getArgs().label(item),
        position: index + 1,
        total,
      })
    );
  }

  #cancelRun() {
    if (this.#run) {
      cancel(this.#run.timer);
      this.#run = null;
    }
  }
}
