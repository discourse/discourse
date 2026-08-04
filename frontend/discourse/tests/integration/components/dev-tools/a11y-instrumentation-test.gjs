import { focus, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import A11yLiveRegions from "discourse/components/a11y/live-regions";
import A11y, {
  disableClearA11yAnnouncementsInTests,
  enableClearA11yAnnouncementsInTests,
} from "discourse/services/a11y";
import {
  attachCapture,
  clearTimeline,
  copyTrace,
  detachCapture,
  disconnectLiveRegions,
  installA11yTap,
  observeLiveRegions,
  resetA11yInstrumentation,
  setConsoleMirror,
  setPaused,
  TIMELINE_LIMIT,
  timelineEntries,
  uninstallA11yTap,
} from "discourse/static/dev-tools/a11y/instrumentation";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

/** MutationObserver callbacks are microtasks settled() does not cover. */
async function settledAnnouncements() {
  await settled();
  await Promise.resolve();
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
      observeLiveRegions();

      this.a11y.announce("twelve results", "polite");
      await settledAnnouncements();

      const intents = entriesOf("intent");
      assert.strictEqual(intents.length, 1, "one intent");
      assert.true(
        intents[0].detail.includes("twelve results"),
        "the intent carries the message"
      );

      const spoken = entriesOf("spoken");
      assert.strictEqual(spoken.length, 1, "one delivery");
      assert.true(
        spoken[0].detail.includes("twelve results"),
        "the delivery carries the region text"
      );
    });

    test("a repeated announcement records intent without a second spoken entry", async function (assert) {
      installA11yTap();
      await render(<template><A11yLiveRegions /></template>);
      observeLiveRegions();

      this.a11y.announce("no results", "polite");
      await settledAnnouncements();
      this.a11y.announce("no results", "polite");
      await settledAnnouncements();

      assert.strictEqual(entriesOf("intent").length, 2, "both calls intend");
      assert.strictEqual(
        entriesOf("spoken").length,
        1,
        "an unchanged region text is not a second delivery"
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
      observeLiveRegions();

      setPaused(true);
      this.a11y.announce("silence", "polite");
      await settledAnnouncements();
      assert.strictEqual(timelineEntries().length, 0, "paused records nothing");

      setPaused(false);
      this.a11y.announce("sound", "polite");
      await settledAnnouncements();
      assert.strictEqual(entriesOf("intent").length, 1, "intent resumes");
      assert.strictEqual(entriesOf("spoken").length, 1, "delivery resumes");
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

      observeLiveRegions();

      const metas = entriesOf("meta");
      assert.strictEqual(metas.length, 1);
      assert.true(
        metas[0].detail.includes("0"),
        "the entry says how many regions are watched"
      );
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
      observeLiveRegions();

      this.a11y.announce("heard", "polite");
      await settledAnnouncements();
      assert.strictEqual(entriesOf("spoken").length, 1);

      disconnectLiveRegions();
      this.a11y.announce("unheard-but-new-text", "polite");
      await settledAnnouncements();
      assert.strictEqual(
        entriesOf("spoken").length,
        1,
        "no deliveries record after disconnect"
      );
      assert.strictEqual(entriesOf("intent").length, 2, "intents still record");
    });
  }
);
