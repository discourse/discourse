import { tracked } from "@glimmer/tracking";
import { trackedArray, trackedMap } from "@ember/reactive/collections";
import { cancel, next, type Timer } from "@ember/runloop";
import Service from "@ember/service";
import { isRailsTesting, isTesting } from "discourse/lib/environment";
import discourseLater from "discourse/lib/later";
import { i18n } from "discourse-i18n";

/** Priority of an ARIA live-region announcement. */
export type AnnouncementType = "polite" | "assertive";

/**
 * One write the service made to a live region on behalf of `announce`, with the calls it
 * carried. Same-tick calls are combined into one write, so text alone cannot say which calls a
 * delivery answers; this does.
 */
export interface AnnouncementRecord {
  /** Increases with every record. */
  id: number;
  /** The live region written to. */
  type: AnnouncementType;
  /** Exactly what was written; "" for a clear. */
  text: string;
  /** Call ids whose message is in `text`, including identical calls merged into one. */
  delivered: readonly number[];
  /** Calls from the same tick that did not make it into `text`, and why. */
  dropped: readonly {
    /** The call id. */
    call: number;
    /** Left out because it restated the region, or discarded by a later empty announcement. */
    reason: "restated" | "cleared";
  }[];
}

/** How many records `announcementHistory` keeps; the oldest are dropped first. */
const ANNOUNCEMENT_HISTORY_LIMIT = 50;

let clearAnnouncements = true;

/**
 * Reset announcements auto-clear functionality by enabling it.
 * When enabled, announcements will automatically clear after their configured delay.
 *
 * This function only works in test environments (Qunit and Rails).
 * Used to restore default behavior where announcements auto-clear.
 *
 * USE ONLY FOR TESTING PURPOSES
 */
export function enableClearA11yAnnouncementsInTests(): void {
  if (isTesting() || isRailsTesting()) {
    clearAnnouncements = true;
  }
}

/**
 * Disable announcements auto-clear functionality.
 * When disabled, announcements will remain visible until manually cleared.
 *
 * This function only works in test environments (Qunit and Rails).
 * Useful for testing that announcements persist for expected duration.
 *
 * USE ONLY FOR TESTING PURPOSES
 */
export function disableClearA11yAnnouncementsInTests(): void {
  if (isTesting() || isRailsTesting()) {
    clearAnnouncements = false;
  }
}

/**
 * Accessibility service that handles screen reader announcements and skip links.
 *
 * Key features:
 * - Makes screen reader announcements using ARIA live regions with polite/assertive modes
 * - Manages skip links for keyboard navigation
 * - Uses tracked state for reactive announcements
 * - Automatically cleans up announcements after configurable delay
 * - Provides both polite and assertive announcement levels
 *
 * @example
 * // Polite announcement that clears after 2 seconds
 * a11y.announce("Page loaded", "polite", 2000);
 *
 * // Assertive immediate announcement
 * a11y.announce("Error occurred", "assertive", 1000);
 */
export default class A11y extends Service {
  /**
   * Flag to control visibility of skip links for keyboard navigation
   */
  @tracked showSkipLinks: boolean = true;

  /**
   * Reference date used to determine if relative dates need to be updated.
   * When this value changes, all relative dates consuming this value will be re-rendered.
   */
  @tracked autoUpdatingRelativeDateRef: Date = new Date();

  /**
   * Untracked map of announcements waiting to be composed by type
   */
  #pendingAnnouncements = new Map<
    AnnouncementType,
    { calls: { id: number; text: string }[]; clearDelay: number }
  >();

  #history: AnnouncementRecord[] = [];

  #liveRegionOutlets = trackedArray<HTMLElement>();

  #nextCallId = 1;

  #nextRecordId = 1;

  #state = new (class {
    /**
     * Map of screen reader announcements by type
     */
    #messages = trackedMap<AnnouncementType, string>();

    /**
     * How many times each region has been written, identical repeats included
     */
    #writes = trackedMap<AnnouncementType, number>();

    /**
     * Map of announcement clear timers by type
     */
    #timers = trackedMap<AnnouncementType, Timer>();

    /**
     * Sets an announcement message with auto-clearing
     * @param type - Type of announcement
     * @param message - Message to announce
     * @param clearDelay - Delay in ms before clearing
     */
    setMessage(
      type: AnnouncementType,
      message: string,
      clearDelay: number
    ): void {
      if (message === "") {
        this.#messages.delete(type);
        this.#scheduleClear(type, 0);
        return;
      }

      this.#write(type, message, clearDelay);
    }

    /**
     * Gets the current announcement message of specified type
     * @param type - Type of announcement to get
     * @returns The announcement message if exists
     */
    getMessage(type: AnnouncementType): string | undefined {
      return this.#messages.get(type);
    }

    /**
     * Gets how many times a region has been written
     * @param type - Type of announcement
     * @returns The number of writes, identical repeats included
     */
    getWriteCount(type: AnnouncementType): number {
      return this.#writes.get(type) ?? 0;
    }

    /**
     * Clears all pending announcement timers
     */
    clearTimers(): void {
      this.#timers.forEach((timer) => {
        if (timer) {
          cancel(timer);
        }
      });
      this.#timers.clear();
    }

    /**
     * Writes the message into the live region and arms its clear timer
     * @param type - Type of announcement
     * @param message - Message to announce
     * @param clearDelay - Delay in ms before clearing
     */
    #write(type: AnnouncementType, message: string, clearDelay: number): void {
      this.#messages.set(type, message);
      this.#writes.set(type, (this.#writes.get(type) ?? 0) + 1);

      if (clearAnnouncements) {
        this.#scheduleClear(type, clearDelay);
      }
    }

    /**
     * Schedule clearing of an announcement after delay
     * @param type - Type of announcement to clear
     * @param clearDelay - Delay in ms before clearing
     */
    #scheduleClear(type: AnnouncementType, clearDelay: number): void {
      const pendingTimer = this.#timers.get(type);
      if (pendingTimer) {
        cancel(pendingTimer);
        this.#timers.delete(type);
      }

      if (clearDelay > 0) {
        const timer = discourseLater(() => {
          // A clear that falls due in the same flush as a newer write runs after it even
          // though the write cancelled it, because Backburner queues every due timer first.
          if (this.#timers.get(type) !== timer) {
            return;
          }

          this.#messages.delete(type);
          this.#timers.delete(type);
        }, clearDelay);
        this.#timers.set(type, timer);
      }
    }
  })();

  /**
   * Cleanup timers when service is destroyed
   */
  willDestroy(): void {
    super.willDestroy();
    this.#pendingAnnouncements.clear();
    this.#state.clearTimers();
  }

  /**
   * Gets the current assertive announcement message
   */
  get assertiveMessage(): string | undefined {
    return this.#state.getMessage("assertive");
  }

  /**
   * Gets the current polite announcement message
   */
  get politeMessage(): string | undefined {
    return this.#state.getMessage("polite");
  }

  /**
   * Where the live regions render: the outlet of the newest open modal dialog, or `undefined`
   * for the page root. Browsers leave everything outside an open `aria-modal` dialog out of the
   * accessibility tree, so regions left at the root go unread while one is open.
   */
  get liveRegionOutlet(): HTMLElement | undefined {
    return this.#liveRegionOutlets.at(-1);
  }

  /**
   * The newest writes made to the live regions, oldest first, as frozen copies.
   */
  get announcementHistory(): readonly AnnouncementRecord[] {
    return Object.freeze(
      this.#history.map((record) =>
        Object.freeze({
          ...record,
          delivered: Object.freeze([...record.delivered]),
          dropped: Object.freeze(
            record.dropped.map((entry) => Object.freeze({ ...entry }))
          ),
        })
      )
    );
  }

  /**
   * Announce a message to screen readers, composing same-type messages in one flush
   * @param message - The message to announce
   * @param type - The announcement type
   * @param clearDelay - Delay in ms before clearing the message
   * @returns The call id, which `announcementHistory` records against this call
   * @throws TypeError - If message is not a string
   * @throws Error - If clearDelay is not positive or type is invalid
   */
  announce(
    message: string,
    type: AnnouncementType = "polite",
    clearDelay: number = 2000
  ): number {
    if (typeof message !== "string") {
      throw new TypeError("The announced message must be a string");
    }

    clearDelay = Math.max(0, Number(clearDelay) || 0);
    if (clearDelay <= 0) {
      throw new Error("The clearDelay must be a positive number");
    }

    if (type !== "assertive" && type !== "polite") {
      throw new Error(
        `Invalid announcement type: ${type}. Expected 'polite' or 'assertive'.`
      );
    }

    const trimmed = message.trim();
    const callId = this.#nextCallId++;

    if (trimmed === "") {
      const discarded = this.#pendingAnnouncements.get(type)?.calls ?? [];
      this.#pendingAnnouncements.delete(type);

      next(() => {
        if (this.isDestroying) {
          return;
        }

        this.#record(
          type,
          "",
          [callId],
          discarded.map(({ id }) => ({ call: id, reason: "cleared" }))
        );
        this.#state.setMessage(type, "", clearDelay);
      });
      return callId;
    }

    const pendingAnnouncement = this.#pendingAnnouncements.get(type);
    if (pendingAnnouncement) {
      pendingAnnouncement.calls.push({ id: callId, text: trimmed });
      pendingAnnouncement.clearDelay = Math.max(
        pendingAnnouncement.clearDelay,
        clearDelay
      );
      return callId;
    }

    const announcement = {
      calls: [{ id: callId, text: trimmed }],
      clearDelay,
    };
    this.#pendingAnnouncements.set(type, announcement);

    // Defer the tracked-state write out of the current render. `announce` is often
    // called from a render-driven data load (e.g. an async content resolution), and
    // writing tracked state synchronously during render trips Ember's
    // backtracking-rerender assertion. `next` runs after the render completes and is
    // awaited by `settled()`; a live region is polled asynchronously, so the one-tick
    // delay is imperceptible.
    next(() => {
      if (this.#pendingAnnouncements.get(type) !== announcement) {
        return;
      }

      this.#pendingAnnouncements.delete(type);

      if (this.isDestroying) {
        return;
      }

      // Dedupe identical texts: repeating the same phrase in one atomic announcement
      // conveys nothing to a screen reader. A `Set` preserves first-occurrence order.
      let messages = [...new Set(announcement.calls.map(({ text }) => text))];

      // A message that only restates what the region already says is news to nobody once the
      // same flush carries something else, and composing it in reads the superseded value
      // aloud first — a count that moved from one to two would be announced as both. Alone it
      // is kept, so re-asserting an unchanged state still reaches the reader.
      if (messages.length > 1) {
        const current = this.#state.getMessage(type);
        messages = messages.filter((text) => text !== current);
      }

      const kept = new Set(messages);
      // Translated because the sentence break differs by script, spacing included.
      const text = messages.join(i18n("a11y_announcement_separator"));

      this.#record(
        type,
        text,
        announcement.calls
          .filter((call) => kept.has(call.text))
          .map(({ id }) => id),
        announcement.calls
          .filter((call) => !kept.has(call.text))
          .map(({ id }) => ({ call: id, reason: "restated" }))
      );
      this.#state.setMessage(type, text, announcement.clearDelay);
    });

    return callId;
  }

  /**
   * How many times a live region has been written, identical repeats included. The live
   * regions render each write in a new element, because VoiceOver stays silent when an
   * element is given the text it last said, even if it was emptied in between.
   * @param type - Type of announcement
   * @returns The number of writes
   */
  liveRegionWriteCount(type: AnnouncementType): number {
    return this.#state.getWriteCount(type);
  }

  /**
   * Renders the live regions inside `element` until it is unregistered. An open modal dialog
   * registers its outlet, so the newest one holds them.
   */
  registerLiveRegionOutlet(element: HTMLElement): void {
    this.#liveRegionOutlets.push(element);
  }

  unregisterLiveRegionOutlet(element: HTMLElement): void {
    const index = this.#liveRegionOutlets.indexOf(element);
    if (index !== -1) {
      this.#liveRegionOutlets.splice(index, 1);
    }
  }

  /**
   * Appends a write to `announcementHistory`, dropping the oldest past the limit.
   *
   * @param type - The live region written to
   * @param text - What is written
   * @param delivered - Call ids whose message is in `text`
   * @param dropped - Calls left out, and why
   */
  #record(
    type: AnnouncementType,
    text: string,
    delivered: number[],
    dropped: AnnouncementRecord["dropped"]
  ): void {
    this.#history.push({
      id: this.#nextRecordId++,
      type,
      text,
      delivered,
      dropped,
    });
    if (this.#history.length > ANNOUNCEMENT_HISTORY_LIMIT) {
      this.#history.shift();
    }
  }
}
