import {
  click,
  focus,
  render,
  settled,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import A11yLiveRegions from "discourse/components/a11y/live-regions";
import A11y, {
  disableClearA11yAnnouncementsInTests,
  enableClearA11yAnnouncementsInTests,
} from "discourse/services/a11y";
import { capabilities } from "discourse/services/capabilities";
import {
  attachCapture,
  attachLiveRegions,
  clearTimeline,
  copyTrace,
  detachCapture,
  disconnectLiveRegions,
  installA11yTap,
  resetA11yInstrumentation,
  setConsoleMirror,
  setPaused,
  TIMELINE_LIMIT,
  timelineEntries,
  uninstallA11yTap,
  watchedLiveRegionCount,
  watchedLiveRegions,
} from "discourse/static/dev-tools/a11y/instrumentation";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

/** MutationObserver callbacks are microtasks settled() does not cover. */
async function settledAnnouncements() {
  await settled();
  await Promise.resolve();
}

/** Apple keyboards print glyphs on the modifiers; everything else does not. */
function appleGlyph(name, glyph) {
  return capabilities.isApple ? glyph : name;
}

function entriesOf(kind) {
  return timelineEntries().filter((entry) => entry.kind === kind);
}

/**
 * Oracle for the a11y dev-tools instrumentation (unit A2). The load-bearing
 * distinction is intent versus delivery: an announce call always records an
 * intent, but only a live-region text CHANGE records a spoken entry, so a
 * deduplicated repeat leaves an intent with no spoken twin.
 */
module(
  "Integration | Component | dev-tools | a11y-instrumentation",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.a11y = this.owner.lookup("service:a11y");
      // The DOM-delivery assertions read the region after settled(), and the
      // test-mode auto-clear would have emptied it by then.
      disableClearA11yAnnouncementsInTests();
    });

    hooks.afterEach(function () {
      resetA11yInstrumentation();
      enableClearA11yAnnouncementsInTests();
    });

    test("an announce call records an intent and its delivery a spoken entry", async function (assert) {
      installA11yTap();
      await render(<template><A11yLiveRegions /></template>);
      attachLiveRegions();

      this.a11y.announce("twelve results", "polite");
      await settledAnnouncements();

      const intents = entriesOf("intent");
      assert.strictEqual(intents.length, 1, "one intent");
      assert.true(
        intents[0].detail.includes("twelve results"),
        "the intent carries the message"
      );

      const spoken = entriesOf("delivered");
      assert.strictEqual(spoken.length, 1, "one delivery");
      assert.true(
        spoken[0].detail.includes("twelve results"),
        "the delivery carries the region text"
      );
    });

    test("a repeated announcement records both deliveries", async function (assert) {
      installA11yTap();
      await render(<template><A11yLiveRegions /></template>);
      attachLiveRegions();

      this.a11y.announce("no results", "polite");
      await settledAnnouncements();
      this.a11y.announce("no results", "polite");
      await settledAnnouncements();

      assert.strictEqual(entriesOf("intent").length, 2, "both calls intend");
      // The region blanks between the two, so the second write is a real text
      // change and is really spoken. Collapsing the pair as a duplicate would
      // hide the repeat-announcement behaviour this panel exists to verify.
      assert.strictEqual(
        entriesOf("delivered").length,
        2,
        "a message repeated after the region idles is a second delivery"
      );
      assert.true(
        entriesOf("meta").some(
          (entry) => entry.label === "live region cleared"
        ),
        "the blank between them is on the timeline"
      );
    });

    test("the tap passes announcements through untouched", async function (assert) {
      installA11yTap();
      await render(<template><A11yLiveRegions /></template>);

      this.a11y.announce("urgent thing", "assertive");
      await settledAnnouncements();

      assert
        .dom("#a11y-announcements-assertive")
        .includesText("urgent thing", "delivery reaches the right region");
    });

    test("install is idempotent and uninstall restores the original", async function (assert) {
      const original = A11y.prototype.announce;

      installA11yTap();
      installA11yTap();
      await render(<template><A11yLiveRegions /></template>);

      this.a11y.announce("once", "polite");
      await settledAnnouncements();
      assert.strictEqual(
        entriesOf("intent").length,
        1,
        "double install records single intents"
      );

      uninstallA11yTap();
      assert.strictEqual(
        A11y.prototype.announce,
        original,
        "the prototype is restored"
      );

      this.a11y.announce("after", "polite");
      await settledAnnouncements();
      assert.strictEqual(
        entriesOf("intent").length,
        1,
        "no intents after uninstall"
      );
      assert
        .dom("#a11y-announcements-polite")
        .includesText("after", "delivery still works without the tap");
    });

    test("pausing drops entries while everything stays attached", async function (assert) {
      installA11yTap();
      await render(<template><A11yLiveRegions /></template>);
      attachLiveRegions();

      setPaused(true);
      this.a11y.announce("silence", "polite");
      await settledAnnouncements();
      assert.strictEqual(timelineEntries().length, 0, "paused records nothing");

      setPaused(false);
      this.a11y.announce("sound", "polite");
      await settledAnnouncements();
      assert.strictEqual(entriesOf("intent").length, 1, "intent resumes");
      assert.strictEqual(entriesOf("delivered").length, 1, "delivery resumes");
    });

    test("the timeline is a ring of the newest entries with monotonic seqs", async function (assert) {
      installA11yTap();

      for (let i = 0; i < TIMELINE_LIMIT + 10; i++) {
        this.a11y.announce(`m${i}`, "polite");
      }
      await settledAnnouncements();

      const entries = timelineEntries();
      assert.strictEqual(entries.length, TIMELINE_LIMIT, "capped");
      assert.strictEqual(
        entries[0].seq,
        11,
        "the oldest surviving entry is the eleventh"
      );
      assert.true(
        entries[entries.length - 1].detail.includes(`m${TIMELINE_LIMIT + 9}`),
        "the newest entry survives"
      );
    });

    // The detail is what the timeline row shows and what `copyTrace` pastes, so
    // a snapshot that reaches neither is a snapshot nobody can read.
    test("an event's detail carries the state the snapshot found", async function (assert) {
      attachCapture();

      await render(
        <template>
          <input
            role="combobox"
            id="cb"
            class="d-combobox__input"
            aria-label="Category"
            aria-expanded="true"
            aria-controls="lb"
            aria-activedescendant="o2"
          />
          <ul role="listbox" id="lb">
            <li role="option" id="o1">Bugs</li>
            <li role="option" id="o2" aria-selected="true">Feature requests</li>
          </ul>
        </template>
      );

      await focus("#cb");

      const { detail } = entriesOf("event")[0];
      assert.true(
        detail.includes("focus=input · role=combobox · Category"),
        "the focused control is named, not reduced to an id"
      );
      assert.true(detail.includes("expanded=true"), "state comes along");
      assert.true(detail.includes("resolves=yes"), "the cursor was followed");
      assert.true(
        detail.includes("position=2 / 2"),
        "the row's place in the set is stated"
      );
      assert.true(
        detail.includes("selected=true"),
        "the row's selection is stated"
      );
      assert.true(
        detail.includes("containment=portaled, claimed by aria-controls"),
        "the listbox is outside the input, and the claim that reaches it is named"
      );
      assert.false(
        detail.includes("agree="),
        "nothing marks a visual cursor, so agreement is not claimed"
      );

      detachCapture();
    });

    test("an event's detail omits what the markup does not state", async function (assert) {
      attachCapture();
      await render(
        <template>
          <button type="button" id="plain">Go</button>
        </template>
      );

      await focus("#plain");

      assert.strictEqual(
        entriesOf("event")[0].detail,
        "focus=button · Go",
        "a plain focus move stays one short line"
      );

      detachCapture();
    });

    test("a visual cursor that has drifted from the ARIA cursor is called out", async function (assert) {
      attachCapture();

      await render(
        <template>
          <input
            role="combobox"
            id="cb"
            aria-label="Category"
            aria-activedescendant="o1"
          />
          <ul role="listbox" id="lb">
            <li role="option" id="o1">Bugs</li>
            <li role="option" id="o2" class="--active">Feature requests</li>
          </ul>
        </template>
      );

      await focus("#cb");

      const { detail, snapshot } = entriesOf("event")[0];
      assert.strictEqual(snapshot.agreement, "diverged");
      assert.true(
        detail.includes("visual and ARIA cursors differ"),
        "the drift is spelled out rather than left to be inferred"
      );

      detachCapture();
    });

    test("keyup entries keep the key that was pressed", async function (assert) {
      attachCapture();
      await render(
        <template><input id="typed" aria-label="Search" /></template>
      );

      await triggerKeyEvent("#typed", "keyup", "ArrowDown");

      assert.true(
        entriesOf("event").some(
          (entry) =>
            entry.label === "keyup" && entry.keys?.join("+") === "ArrowDown"
        ),
        "arrow keys are distinguishable, which is the point of the timeline"
      );

      detachCapture();
    });

    // `keyup` fires per physical key, so Meta+C ends in a `c` release and then
    // a `Meta` release. The chord belongs on the first; the second is noise.
    test("a chord is one entry, named as it was pressed", async function (assert) {
      attachCapture();
      await render(
        <template><input id="typed" aria-label="Search" /></template>
      );

      // `triggerKeyEvent` rejects a lowercase key, so this reads `C` where a
      // browser would report `c`. The case is the helper's, not the panel's.
      await triggerKeyEvent("#typed", "keyup", "C", { metaKey: true });
      await triggerKeyEvent("#typed", "keyup", "Meta");
      await triggerKeyEvent("#typed", "keyup", "Tab", { shiftKey: true });

      assert.deepEqual(
        entriesOf("event").map((entry) => entry.keys),
        [
          [appleGlyph("Meta", "\u2318"), "C"],
          [appleGlyph("Shift", "\u21e7"), "Tab"],
        ],
        "the modifier rides the chord rather than trailing it with a row"
      );

      detachCapture();
    });

    // Screen readers are driven by held modifiers, and a keypress that leaves
    // no trace cannot be told apart from capture being broken.
    test("a modifier pressed on its own still records", async function (assert) {
      attachCapture();
      await render(
        <template><input id="typed" aria-label="Search" /></template>
      );

      await triggerKeyEvent("#typed", "keyup", "Meta");
      await triggerKeyEvent("#typed", "keyup", "Control");

      assert.deepEqual(
        entriesOf("event").map((entry) => entry.keys),
        [[appleGlyph("Meta", "\u2318")], [appleGlyph("Control", "\u2303")]],
        "no chord claimed them, so they stand on their own"
      );

      detachCapture();
    });

    test("capture records interactions with a snapshot and excludes the toolbar", async function (assert) {
      attachCapture();

      await render(
        <template>
          <button type="button" id="real">page control</button>
          <div class="dev-tools-toolbar">
            <button type="button" id="chrome">panel control</button>
          </div>
        </template>
      );

      await focus("#real");

      const events = entriesOf("event");
      assert.strictEqual(events.length, 1, "the page interaction records");
      assert.true(events[0].label.includes("focusin"));
      assert.true(Boolean(events[0].snapshot), "the entry carries a snapshot");

      await focus("#chrome");

      assert.strictEqual(
        entriesOf("event").length,
        1,
        "the panel's own chrome never enters the trace"
      );

      detachCapture();
      await focus("#real");

      assert.strictEqual(
        entriesOf("event").length,
        1,
        "nothing records after detach"
      );
    });

    test("watching no regions is a loud meta entry, not silence", async function (assert) {
      await render(<template><div /></template>);

      attachLiveRegions();

      const metas = entriesOf("meta");
      assert.strictEqual(metas.length, 1);
      assert.true(
        metas[0].detail.includes("0"),
        "the entry says how many regions are watched"
      );
    });

    // A running total climbs every time a modal opens and closes, and a number
    // that only ever rises cannot tell a leak from bookkeeping. The count is of
    // regions present now, and each arrival and departure is named.
    test("a region that leaves is released rather than counted forever", async function (assert) {
      attachCapture();
      await render(
        <template>
          <button type="button" id="go">go</button>
        </template>
      );
      attachLiveRegions();

      const fixture = document.getElementById("qunit-fixture");
      const region = document.createElement("div");
      region.id = "transient-region";
      region.setAttribute("aria-live", "polite");
      fixture.append(region);

      await focus("#go");
      assert.strictEqual(watchedLiveRegionCount(), 1, "the arrival is counted");
      assert.true(
        entriesOf("meta").some(
          (entry) =>
            entry.label === "live region joined" &&
            entry.detail.includes("#transient-region")
        ),
        "and named, so it can be traced to whatever rendered it"
      );

      region.remove();
      // Not `focus` again: the button already has focus, so no focusin fires
      // and nothing would rescan.
      await click("#go");

      assert.strictEqual(
        watchedLiveRegionCount(),
        0,
        "the departure brings the count back down"
      );
      assert.true(
        entriesOf("meta").some(
          (entry) =>
            entry.label === "live region left" &&
            entry.detail.includes("#transient-region")
        ),
        "and is named too"
      );
      assert.deepEqual(watchedLiveRegions(), [], "nothing is still held");

      detachCapture();
    });

    test("attaching is additive, so a region is never observed twice", async function (assert) {
      installA11yTap();
      await render(<template><A11yLiveRegions /></template>);

      attachLiveRegions();
      attachLiveRegions();
      attachLiveRegions();

      assert.strictEqual(
        watchedLiveRegionCount(),
        2,
        "re-attaching does not re-count the same regions"
      );

      this.a11y.announce("counted once", "polite");
      await settledAnnouncements();

      assert.strictEqual(
        entriesOf("delivered").length,
        1,
        "one delivery is one entry, not one per attach"
      );
    });

    // The shared regions render at the end of the application template, after
    // the panel's own subtree, and a modal brings its own later still. A
    // one-shot scan on setup attaches to nothing and then reports a silence
    // indistinguishable from a page that never announced.
    test("a region that appears after setup is picked up on the next event", async function (assert) {
      installA11yTap();
      attachCapture();
      await render(
        <template>
          <button type="button" id="later">go</button>
        </template>
      );

      attachLiveRegions();
      assert.strictEqual(
        watchedLiveRegionCount(),
        0,
        "nothing to watch at setup"
      );

      const region = document.createElement("div");
      region.id = "late-region";
      region.setAttribute("aria-live", "polite");
      document.getElementById("qunit-fixture").append(region);

      await focus("#later");

      assert.strictEqual(
        watchedLiveRegionCount(),
        1,
        "the event rescan finds the region that arrived late"
      );

      region.textContent = "arrived late";
      await settledAnnouncements();

      assert.strictEqual(
        entriesOf("delivered").length,
        1,
        "its delivery is observed rather than missed"
      );
      detachCapture();
    });

    test("the console mirror is off by default", async function (assert) {
      installA11yTap();
      const seen = [];
      /* eslint-disable no-console */
      const original = console.log;
      console.log = (...args) => seen.push(args.join(" "));

      try {
        this.a11y.announce("quiet", "polite");
        await settledAnnouncements();
        assert.strictEqual(
          seen.filter((line) => line.includes("[a11y]")).length,
          0,
          "no mirroring unless asked"
        );

        setConsoleMirror(true);
        this.a11y.announce("loud", "polite");
        await settledAnnouncements();
        assert.true(
          seen.some((line) => line.includes("[a11y]") && line.includes("loud")),
          "mirroring follows the flag"
        );
      } finally {
        console.log = original;
        /* eslint-enable no-console */
      }
    });

    test("the trace carries every entry with its sequence number", async function (assert) {
      installA11yTap();

      this.a11y.announce("first", "polite");
      this.a11y.announce("second", "polite");
      await settledAnnouncements();

      const trace = copyTrace();
      assert.true(trace.includes("#1"), "sequence numbers survive");
      assert.true(trace.includes("first"));
      assert.true(trace.includes("second"));
    });

    test("clearing the timeline never resets the sequence", async function (assert) {
      installA11yTap();

      this.a11y.announce("one", "polite");
      await settledAnnouncements();
      clearTimeline();
      assert.strictEqual(timelineEntries().length, 0);

      this.a11y.announce("two", "polite");
      await settledAnnouncements();
      assert.true(
        timelineEntries()[0].seq > 1,
        "sequence numbers stay monotonic across clears"
      );
    });

    test("disconnecting the observers stops spoken entries", async function (assert) {
      installA11yTap();
      await render(<template><A11yLiveRegions /></template>);
      attachLiveRegions();

      this.a11y.announce("heard", "polite");
      await settledAnnouncements();
      assert.strictEqual(entriesOf("delivered").length, 1);

      disconnectLiveRegions();
      this.a11y.announce("unheard-but-new-text", "polite");
      await settledAnnouncements();
      assert.strictEqual(
        entriesOf("delivered").length,
        1,
        "no deliveries record after disconnect"
      );
      assert.strictEqual(entriesOf("intent").length, 2, "intents still record");
    });
  }
);
