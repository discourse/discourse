import { isDestroying, registerDestructor } from "@ember/destroyable";
import { action } from "@ember/object";
import { cancel, next as nextRunloop } from "@ember/runloop";
import { makeArray } from "discourse/lib/helpers";
import discourseLater from "discourse/lib/later";
import type A11y from "discourse/services/a11y";
import { LOADING_FEEDBACK_DELAY } from "discourse/ui-kit/select/-internals/coordinators/load-feedback";
import type { SelectionOrigin } from "discourse/ui-kit/select/-internals/engine/selection-updates";
import SelectEngine, {
  type SelectItem,
  type SelectValue,
} from "discourse/ui-kit/select/select-engine";

// How long a settled query waits before it is reported. Long, and deliberately so: a screen
// reader echoes what is being typed, and that echo interrupts anything the page says underneath
// it — so a report fired promptly is begun and then abandoned mid-word, which is worse than one
// that arrives late. The wait has to outlast the echo, not merely the typing. This value matches
// what long-standing accessible autocomplete implementations have converged on for the same
// collision. Client filtering stays un-debounced, so the list itself never lags a keystroke.
const RESULT_REPORT_DELAY = 1400;

interface PendingCount {
  timer: ReturnType<typeof discourseLater>;
  query: string;
  message: string;
  activeKey: string | null;
  previous: { query: string; message: string } | null;
}

interface ScheduleReportOptions {
  repeatable?: boolean;
}

interface SelectAnnouncerOptions {
  /** Whether list-state reports may speak at this moment. Selection reports remain ungated. */
  canReport?: () => boolean;
  a11y: A11y;
  engine: SelectEngine;
  getActiveOptionKey: () => string | null;
  reannounceActive: () => boolean;
  getShouldSuppressEntryCount: () => boolean;
  /**
   * Whether a pending reveal has waited long enough to show its frontier placeholders. The
   * "loading more" report follows the same signal, so it is spoken in the render that draws them.
   */
  isRevealDue?: () => boolean;
}

interface ValueChangedOptions {
  origin?: SelectionOrigin;
  reason?: "clear";
  onAddedWithQuery: () => void;
}

export default class SelectAnnouncer {
  #a11y: A11y;
  #canReport: () => boolean;
  #suppressionTimers = new Set<ReturnType<typeof nextRunloop>>();
  #updateTimer?: ReturnType<typeof discourseLater>;
  #engine: SelectEngine;
  #getActiveOptionKey: () => string | null;
  #getShouldSuppressEntryCount: () => boolean;
  #isRevealDue: () => boolean;
  #reannounceActive: () => boolean;

  // Deduping on the message rather than a count keeps a change silent whenever it does not
  // change what the message says.
  //
  // Scoped to the query as well, because the same count for a *different* query is news: a reader
  // who types on and hears nothing has no way to tell a settled search from a dropped keystroke.
  #lastAnnouncedCount: { query: string; message: string } | null = null;

  /**
   * The query whose paged set already announced a known total. More pages for it can move that
   * figure as transformers hide or add rows, and each row's `aria-setsize` already carries the new
   * value, so a reveal stays quiet. A cursor source is the exception: it has no total until its
   * last page declares completeness, so that one reveal legitimately announces.
   */
  #knownTotalQuery: string | null = null;

  // A count waiting to learn whether the cursor moved — see `announceCount`. Holds the message,
  // the query it describes, where the cursor sat when it was scheduled, and what was last known,
  // so the resolve can tell a new search from more rows for the same one.
  #pendingCount?: PendingCount;

  #suppressNextCount = false;

  // Whether a "loading more" was announced and still owes its completion.
  #revealAnnounced = false;

  // The last limit message announced, so re-crossing the cap boundary does not re-read it.
  #lastAnnouncedLimit: string | null = null;

  // The last keep-typing "characters remaining" announced, so a repeat isn't re-read.
  #lastAnnouncedRemaining: number | null = null;

  // Keyed on the query, not a flag: the hint unmounts and remounts as the window grows, and
  // only a new query should re-read it.
  #narrowAnnouncedFor: string | null = null;

  constructor({
    a11y,
    canReport = () => true,
    engine,
    getActiveOptionKey,
    reannounceActive,
    getShouldSuppressEntryCount,
    isRevealDue = () => false,
  }: SelectAnnouncerOptions) {
    this.#a11y = a11y;
    this.#canReport = canReport;
    this.#engine = engine;
    this.#getActiveOptionKey = getActiveOptionKey;
    this.#reannounceActive = reannounceActive;
    this.#getShouldSuppressEntryCount = getShouldSuppressEntryCount;
    this.#isRevealDue = isRevealDue;
    registerDestructor(this, () => this.cancelPending());
  }

  /** Whether a pending reveal is due its report; the list re-runs {@link announceReveal} on it. */
  get revealDue(): boolean {
    return this.#isRevealDue();
  }

  /**
   * Politely announces the result count to screen readers via the shared `a11y`
   * service (never a per-component live region, never assertive), skipping repeats.
   *
   * Reports the set size, matching `aria-setsize`, so a transformer that hides or adds rows
   * changes both together. The source's total only chooses the wording: "results" when it is
   * known, "results loaded" while a cursor source is still paging.
   */
  @action
  announceCount(
    _element: HTMLElement,
    [setSize, total, query]: [number, number | undefined, string?]
  ): void {
    if (!this.#canReport()) {
      return;
    }

    // Mid-load the rows on screen are the previous query's and the total is already cleared,
    // so any count now describes stale rows. Settling re-fires this with the real numbers.
    if (this.#engine.serverPending) {
      return;
    }

    const settledQuery = query ?? "";
    if (this.#engine.isAsync) {
      if (this.#knownTotalQuery === settledQuery) {
        return;
      }
      this.#knownTotalQuery = total == null ? null : settledQuery;
    }
    const message =
      total == null
        ? this.#engine.text("resultsLoaded", { count: setSize })
        : this.#engine.text("resultsCount", { count: setSize });

    if (this.#suppressNextCount) {
      this.#suppressNextCount = false;
      // Record the suppressed message as last-known, or a later run of the same query would be
      // treated as fresh news and announce what was deliberately swallowed.
      this.#lastAnnouncedCount = { query: settledQuery, message };
      return;
    }

    // Whether this count is worth saying depends on something that has not happened yet: the
    // roving cursor re-seeds later in this same render, and a cursor that moves takes the voice
    // with it. So hold the message and decide once it has settled.
    this.#scheduleReport(settledQuery, message);
  }

  /**
   * A freshly mounted listbox is a fresh context, so the count always announces on open even
   * when it matches what the previous open announced. Updates while the list stays mounted
   * keep deduping through {@link announceCount}.
   *
   * Except when opening seeds a cursor. The seeded row is announced with its own position in the
   * set, from `aria-posinset`/`aria-setsize` — "1 of 15" — so a count fired in the same moment
   * restates it through a second channel, and assistive tech speaks one of the two and drops the
   * other. Observed against VoiceOver on both the select-only and query-input variants: the open
   * that spoke the count never spoke the row, and the open that spoke the row never spoke the
   * count, alternating between opens. The row wins because it says strictly more, and in the
   * reader's own verbosity settings rather than ours.
   *
   * Only the count at *entry* is affected. A count that changes while the list stays open has no
   * row announcement to compete with, and remains the only thing reporting the new set size.
   *
   * Recorded rather than skipped outright, so a later count change while the list stays open is
   * still a change and still announces.
   */
  @action
  announceCountOnEntry(
    element: HTMLElement,
    args: [number, number | undefined, string?]
  ): void {
    if (!this.#canReport()) {
      return;
    }

    this.#lastAnnouncedCount = null;
    this.#knownTotalQuery = null;

    if (this.#getShouldSuppressEntryCount()) {
      this.#suppressNextCount = true;
    }

    this.announceCount(element, args);
  }

  /**
   * Politely announces an empty result set — the count announcement for a count of zero.
   *
   * {@link announceCount} hangs off the list, which `{{#if items.length}}` unmounts the moment
   * a query matches nothing, so the one outcome a reader most needs reported was the only one
   * nothing reported. Shares the count's dedupe slot and its suppression flag rather than
   * owning new ones: "no results" and "3 results" answer the same question about the same
   * query, and a suppressed refilter must swallow either identically.
   *
   * Unlike {@link announceCount} there is no `serverPending` bail. A stale *count* is possible
   * mid-flight because retention keeps the previous rows on screen; a stale *empty* is not —
   * the empty branch renders only once a load has resolved to nothing.
   *
   * Held for the same delay as a count, and for a sharper reason. Emptying the list destroys the
   * element the query input's `aria-controls` names, so the control momentarily points at nothing
   * and its `aria-activedescendant` is stripped; a screen reader answers that by re-introducing the
   * whole combobox, and that speech preempts anything said underneath it. Reported immediately,
   * this was begun and abandoned — heard as "no results" arriving only sometimes.
   *
   * Both row branches in `#resolvePendingCount` are inert here by construction: with no rows
   * the cursor cannot have moved to one, and the roving API is released along with the listbox, so
   * there is nothing to ask for a re-read.
   */
  @action
  announceNoResults(_element: HTMLElement, [query]: [string?] = []): void {
    if (!this.#canReport()) {
      return;
    }

    // An empty text still replaces a held count below; it is just never spoken.
    const message = this.#engine.text("noResults");
    const settledQuery = query ?? "";

    if (this.#suppressNextCount) {
      this.#suppressNextCount = false;
      this.#cancelPendingCount();
      this.#lastAnnouncedCount = { query: settledQuery, message };
      return;
    }

    // Replaces any held count rather than queueing behind it: the rows that count described are
    // gone, and reporting them now would describe a list the reader can no longer reach.
    this.#scheduleReport(settledQuery, message, { repeatable: true });
  }

  /**
   * Politely reports a server reveal, which is otherwise silent until its frontier placeholders
   * appear. Runs again when the reveal settles or becomes due, and speaks only once it is due, so
   * a fast page says nothing.
   */
  @action
  announceReveal(): void {
    if (!this.#canReport()) {
      this.#cancelReveal();
      return;
    }

    // A new query is also pending and also retains its rows, but it is not more results — its
    // own count announcement covers it when it lands.
    if (this.#engine.serverRevealPending) {
      if (this.#isRevealDue() && !this.#revealAnnounced) {
        this.#revealAnnounced = true;
        this.#say(this.#engine.text("loadingMore"));
      }
      return;
    }

    if (this.#revealAnnounced && !this.#engine.serverPending) {
      this.#revealAnnounced = false;
      this.#say(this.#engine.text("loadingComplete"));
    }
  }

  /**
   * Announces the keep-filtering hint once per query. The visible status node stays for
   * sighted users; a live region announces unreliably on the render that mounts it.
   */
  @action
  announceNarrow(): void {
    if (!this.#canReport()) {
      return;
    }

    const filter = this.#engine.filter;
    if (filter === this.#narrowAnnouncedFor) {
      return;
    }
    this.#narrowAnnouncedFor = filter;
    // Longer than the default window: the cap is typically reached while scrolling, when a
    // screen reader is still voicing option changes and would miss a short-lived message.
    this.#say(this.#engine.text("maxLoaded"), 5000);
  }

  /**
   * Politely announces the keep-typing hint as the query grows below `@minChars`. Routed through
   * the shared `a11y` service (like the count) rather than the visible `role="status"` node,
   * which a freshly-mounted live region announces unreliably. Deduped on the remaining count.
   */
  @action
  announceMinChars(
    _element: HTMLElement,
    [remaining]: [number, ...dependencies: unknown[]]
  ): void {
    if (!this.#canReport()) {
      return;
    }

    if (remaining === this.#lastAnnouncedRemaining) {
      return;
    }
    this.#lastAnnouncedRemaining = remaining;
    this.#say(this.#engine.text("minChars", { count: remaining }));
  }

  /**
   * A fresh entry into the below-threshold state (the hint mounting) always announces, even when
   * the remaining count matches what was last announced before the user briefly rose above the
   * threshold — otherwise re-entering the same partial query would stay silent. Updates while the
   * hint stays mounted keep deduping through {@link announceMinChars}.
   */
  @action
  announceMinCharsOnEntry(element: HTMLElement, args: [number]): void {
    if (!this.#canReport()) {
      return;
    }

    this.#lastAnnouncedRemaining = null;
    this.announceMinChars(element, args);
  }

  /**
   * Announces the limit hint through the shared `a11y` service — the visible node keeps
   * `role="status"` for sighted users, but a freshly-mounted live region announces unreliably,
   * so the message is spoken here instead. Deduped on the text while the hint stays mounted, so an
   * in-place message swap that repeats reads only once.
   */
  @action
  announceLimit(
    _element: HTMLElement,
    [message]: [string, ...dependencies: unknown[]]
  ): void {
    if (!this.#canReport()) {
      return;
    }

    if (message === this.#lastAnnouncedLimit) {
      return;
    }
    this.#lastAnnouncedLimit = message;
    this.#say(message);
  }

  /**
   * A fresh entry into a limit state (the hint mounting) always announces, even when the message
   * matches what was last announced before the hint briefly unmounted — otherwise re-reaching the
   * cap, or reopening a select that is still at the cap, would stay silent. Later in-place updates
   * keep deduping through {@link announceLimit}.
   */
  @action
  announceLimitOnEntry(element: HTMLElement, args: [string]): void {
    if (!this.#canReport()) {
      return;
    }

    this.#lastAnnouncedLimit = null;
    this.announceLimit(element, args);
  }

  /** Announces that keyboard activation is held until the replacement results arrive. */
  announceStillLoading(): void {
    if (!this.#canReport()) {
      return;
    }

    this.#say(this.#engine.text("stillLoading"));
  }

  /**
   * Drops the dedupe keys whose subject is the open session rather than a mounted node, so a
   * reopened panel is a fresh context.
   *
   * Deliberately NOT in `releaseListbox`. That runs whenever `<DVirtualList>` unmounts, which
   * also happens mid-session when a slow re-query swaps in the skeleton — resetting there would
   * re-read the narrow hint on every reload and throw away a reveal's owed completion. It is the
   * same distinction `releaseLoadFeedback` already draws for the outgoing row count.
   *
   * Unguarded by the open→closed transition, like the query reset on close: a spurious close
   * only fires when the panel is already shut, where clearing is inert.
   */
  releaseSession(): void {
    // A count still waiting on the cursor describes a list the reader has closed, and would be
    // read out over whatever they moved on to.
    this.#cancelPendingCount();
    // Keyed on the query, and closing resets the query to "" — so without this the next open
    // compares "" against "" and the hint stays silent for the rest of the component's life.
    this.#narrowAnnouncedFor = null;
    // A "loading more" interrupted by a close otherwise leaves its debt standing, and the next
    // open's first pending→settled transition pays it as a completion nobody started.
    this.#cancelReveal();
  }

  /** Invalidates reports about the previous list without ending the open session. */
  reloadList(): void {
    this.#cancelPendingCount();
    this.#knownTotalQuery = null;
    this.#lastAnnouncedCount = null;
    this.#suppressNextCount = false;
    this.#cancelReveal();
  }

  /** Confirms programmatic intent even when the controlled value does not change. */
  reconfirm(item: SelectItem, origin: SelectionOrigin): void {
    if (!this.#engine.multiple && (origin.programmatic || origin.record)) {
      this.#say(
        this.#engine.text("itemSelected", {
          item: this.#engine.getSelectionLabel(item),
        })
      );
    }
  }

  /** Speaks a batch that added nothing, so the skipped rows are not met with silence. */
  bulkUnchanged({ held, limit }: { held: number; limit: number }): void {
    if (!this.#canReport()) {
      return;
    }
    this.suppressCount();
    this.#say(
      limit === 0
        ? this.#engine.text("allAlreadySelected")
        : this.#bulkSummary(0, held, limit)
    );
  }

  /** Delays feedback so work that finishes quickly stays silent. */
  updateStarted(isCurrent: () => boolean): void {
    cancel(this.#updateTimer);
    this.#updateTimer = discourseLater(() => {
      this.#updateTimer = undefined;
      if (!isDestroying(this) && isCurrent()) {
        this.#say(this.#engine.text("updatingSelection"));
      }
    }, LOADING_FEEDBACK_DELAY);
  }

  /** Prevents a batch or its query reset from being followed by a result-count report. */
  suppressCount(): void {
    this.#cancelPendingCount();
    this.#suppressNextCount = true;
    this.#resetSuppressionNextRunloop();
  }

  valueChanged(
    oldValues: SelectValue,
    nextValues: SelectValue,
    { onAddedWithQuery, origin, reason }: ValueChangedOptions
  ): void {
    if (origin?.bulk) {
      const { added, held, limit } = origin.bulk;
      this.suppressCount();
      this.#say(this.#bulkSummary(added, held, limit));
      return;
    }
    if (reason === "clear" && this.#engine.hasValue) {
      this.#say(this.#engine.text("selectionCleared"));
      return;
    }
    if (this.#engine.multiple) {
      const { added, removed } = this.#engine.diffValues(
        makeArray(oldValues),
        makeArray(nextValues)
      );

      if (added !== undefined) {
        const item = this.#engine.resolveSingleSync(added);
        this.#say(
          this.#engine.text("itemAdded", {
            item: item ? this.#engine.getSelectionLabel(item) : String(added),
          })
        );
        if (this.#engine.filter !== "") {
          this.#suppressNextCount = true;
          onAddedWithQuery();
          this.#resetSuppressionNextRunloop();
        }
      } else if (removed !== undefined) {
        const item = this.#engine.resolveSingleSync(removed);
        this.#say(
          this.#engine.text("itemRemoved", {
            item: item ? this.#engine.getSelectionLabel(item) : String(removed),
          })
        );
      }
    } else if (nextValues == null && this.#engine.hasValue) {
      // Choosing a value is conveyed by the row's own selected state and by the trigger reading
      // back the new value. Clearing has neither: the row simply stops being selected and the
      // trigger's name changes, and a name change on an already-focused element is not reliably
      // re-read. So the one single-select transition that needs saying out loud is this one.
      this.#say(this.#engine.text("selectionCleared"));
    } else if (origin && nextValues != null) {
      const item = this.#engine.resolveSingleSync(nextValues);
      if (item) {
        this.reconfirm(item, origin);
      }
    }
  }

  /** Cancels every deferred report, including delayed selection-update feedback. */
  cancelPending(): void {
    this.#cancelPendingCount();
    this.#cancelReveal();
    cancel(this.#updateTimer);
    this.#updateTimer = undefined;
    for (const timer of this.#suppressionTimers) {
      cancel(timer);
    }
    this.#suppressionTimers.clear();
    this.#suppressNextCount = false;
  }

  /**
   * Composes a batch's parts, leaving out the empty ones. An empty summary text drops the whole
   * announcement, since its parts were never meant to be spoken alone.
   */
  #bulkSummary(added: number, held: number, limit: number): string {
    let message = this.#engine.text("itemsAdded", { count: added });
    for (const [key, count] of [
      ["itemsNotAddedHeld", held],
      ["itemsNotAddedLimit", limit],
    ] as const) {
      const part = count > 0 ? this.#engine.text(key, { count }) : "";
      if (!part) {
        continue;
      }
      if (!message) {
        message = part;
        continue;
      }
      message = this.#engine.text("bulkAddSummary", {
        added: message,
        not_added: part,
      });
      if (!message) {
        return "";
      }
    }
    return message;
  }

  /** Speaks politely; an empty text is "no text", and announcing it would clear the queue. */
  #say(message: string, duration?: number): void {
    if (!message.trim()) {
      return;
    }
    if (duration === undefined) {
      this.#a11y.announce(message, "polite");
    } else {
      this.#a11y.announce(message, "polite", duration);
    }
  }

  #cancelReveal(): void {
    this.#revealAnnounced = false;
  }

  #resetSuppressionNextRunloop(): void {
    const timer = nextRunloop(() => {
      this.#suppressionTimers.delete(timer);
      this.#suppressNextCount = false;
    });
    this.#suppressionTimers.add(timer);
  }

  #cancelPendingCount(): void {
    if (this.#pendingCount) {
      cancel(this.#pendingCount.timer);
      this.#pendingCount = undefined;
    }
  }

  /**
   * Decides what a held count should do, now that the cursor has settled. Three outcomes, and
   * only one of them is the count.
   *
   * **The cursor moved.** The row that became active announced itself along with its position in
   * the set — "Banana, 1 of 1" — so a count fired for the same change restates it through a
   * second channel and assistive tech speaks one of the two and drops the other. That is the
   * collision {@link announceCountOnEntry} resolves at the open, arriving here through every
   * later query.
   *
   * **A new search left the cursor where it was.** Narrowing two matches to the first one keeps
   * the cursor on that row while its `aria-setsize` goes from 2 to 1, and nothing re-reads it — so
   * the reader learns the count changed but never which option survived. Ask for the row again
   * instead: it reports the match and the new set together, and in the reader's own verbosity
   * settings. A count reaching here always describes a set that changed, since an unchanged one
   * never gets this far.
   *
   * **The count, for the cases with no row to carry it.** No cursor at all (a variant that waits
   * for the reader to move), or more rows arriving under a stationary cursor, where the set grew
   * without the reader's question changing.
   */
  #resolvePendingCount(): void {
    const pending = this.#pendingCount;
    this.#pendingCount = undefined;
    if (!pending || isDestroying(this) || !this.#canReport()) {
      return;
    }

    this.#lastAnnouncedCount = {
      query: pending.query,
      message: pending.message,
    };

    const activeOptionKey = this.#getActiveOptionKey();
    if (activeOptionKey != null && activeOptionKey !== pending.activeKey) {
      return;
    }

    // Only when the reader's question changed. More rows arriving for the *same* question already
    // have their own announcement, and re-reading the row would compete with it.
    const isNewSearch = pending.previous?.query !== pending.query;
    if (isNewSearch && activeOptionKey != null && this.#reannounceActive()) {
      return;
    }

    this.#say(pending.message);
  }

  /**
   * Holds a report until the reader has stopped typing and the cursor has settled, capturing what
   * the decision in `#resolvePendingCount` will be made against.
   */
  #scheduleReport(
    query: string,
    message: string,
    { repeatable = false }: ScheduleReportOptions = {}
  ): void {
    // A query that lands on exactly the set it already had is not news, whatever the reader typed
    // to get there — and there is no honest way to say it. Announcing the unchanged count is
    // audible only when the region's clear timer happens to have fired since it was last spoken,
    // so it comes and goes with the reader's typing rhythm, which is the erratic re-announcement
    // this work set out to remove. The typing echo already confirms the keystroke landed.
    if (!repeatable && this.#lastAnnouncedCount?.message === message) {
      return;
    }

    this.#cancelPendingCount();
    this.#pendingCount = {
      query,
      message,
      activeKey: this.#getActiveOptionKey(),
      previous: this.#lastAnnouncedCount,
      timer: discourseLater(
        () => this.#resolvePendingCount(),
        RESULT_REPORT_DELAY
      ),
    };
  }
}
