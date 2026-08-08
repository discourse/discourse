import { settled } from "@ember/test-helpers";

/**
 * Records what the shared live regions actually announce, in order.
 *
 * Tiers that assert attributes cannot see this class of defect. Every attribute can be individually
 * correct while the *announcement* is wrong — spoken twice, spoken when it should be silent, or
 * silent when it should speak. Several open items in `SANDBOX-A11Y-REMEDIATION.md` are exactly that
 * shape, including the one this was built for: two announcements racing for one voice, where a
 * screen reader speaks one and drops the other, so the user hears neither reliably.
 *
 * This is a deliberately small, owned alternative to a third-party virtual screen reader. It
 * asserts *our* announcements rather than a simulator's invented phrasing, so a failure names a
 * defect in this codebase instead of a divergence from someone's spec approximation. The mechanics
 * are the ones already proven in the styleguide's `select-aria-probe.gjs`.
 *
 * @example
 * const announcements = trackAnnouncements();
 * await click("[role='combobox']");
 * assert.deepEqual(announcements.phrases(), []);  // opening seeds a cursor, so it stays silent
 * announcements.stop();
 */

const REGIONS = [
  { id: "a11y-announcements-polite", politeness: "polite" },
  { id: "a11y-announcements-assertive", politeness: "assertive" },
];

/**
 * Starts recording. The caller must have rendered `A11yLiveRegions` already.
 *
 * Throws when a region is missing rather than reporting silence. That is the whole point: the
 * styleguide probe originally attached before the shared regions mounted and then reported nothing,
 * which is indistinguishable from a component that never announced — the failure mode most likely
 * to make a green test meaningless.
 */
export function trackAnnouncements() {
  const entries = [];
  const observers = [];

  for (const { id, politeness } of REGIONS) {
    const element = document.getElementById(id);

    if (!element) {
      throw new Error(
        `trackAnnouncements: #${id} is not in the DOM. Render <A11yLiveRegions /> in the test ` +
          `before tracking, or a silent component and a missing region look identical.`
      );
    }

    // `aria-atomic="true"` means the region is re-read whole on any change, so the unit to record is
    // the region's text after each mutation, not the individual nodes that changed.
    const observer = new MutationObserver(() => {
      const text = element.textContent.trim();

      // A clear is not an announcement. The service blanks the region after a delay, and recording
      // that would turn every message into two entries.
      if (!text) {
        return;
      }

      // The region is re-rendered rather than appended to, so an unchanged message can mutate the
      // DOM without being spoken again.
      const previous = entries
        .filter((e) => e.politeness === politeness)
        .at(-1);
      if (previous?.text === text) {
        return;
      }

      entries.push({ politeness, text });
    });

    observer.observe(element, {
      childList: true,
      characterData: true,
      subtree: true,
    });
    observers.push(observer);
  }

  return {
    /**
     * Announcements so far, as `"<politeness>: <text>"`, in the order they were made.
     *
     * The politeness prefix matters: a count that should be polite arriving as `assertive` will
     * interrupt whatever the user was listening to.
     */
    phrases() {
      return entries.map((entry) => `${entry.politeness}: ${entry.text}`);
    },

    /** Just the texts, for when only the sequence matters. */
    texts() {
      return entries.map((entry) => entry.text);
    },

    /** How many announcements a given politeness made — the debounce/duplication assertion. */
    count(politeness) {
      return entries.filter((entry) => entry.politeness === politeness).length;
    },

    /** Drops what has been recorded so an assertion can be scoped to the next action alone. */
    clear() {
      entries.length = 0;
    },

    stop() {
      observers.forEach((observer) => observer.disconnect());
      observers.length = 0;
    },
  };
}

/**
 * Settles the runloop and then lets the MutationObserver microtask flush.
 *
 * `settled()` resolves when Ember is idle, but a MutationObserver callback is queued as a microtask
 * and may not have run yet — reading the log immediately after `settled()` can miss the last entry.
 * Awaiting an already-resolved promise yields to the microtask queue without introducing a timer,
 * which would be an arbitrary wait.
 */
export async function settledAnnouncements() {
  await settled();
  await Promise.resolve();
}
