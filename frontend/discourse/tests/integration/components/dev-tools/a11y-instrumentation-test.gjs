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

    test("keydown entries keep the key that was pressed", async function (assert) {
      attachCapture();
      await render(
        <template><input id="typed" aria-label="Search" /></template>
      );

      await triggerKeyEvent("#typed", "keydown", "ArrowDown");

      assert.true(
        entriesOf("event").some(
          (entry) =>
            entry.label === "keydown" && entry.keys?.join("+") === "ArrowDown"
        ),
        "arrow keys are distinguishable, which is the point of the timeline"
      );

      detachCapture();
    });

    /*
     * On press the modifier arrives FIRST and nothing yet says whether a chord
     * follows, which is the opposite of release, where the chord is already
     * recorded and its trailing modifier is redundant. Capture cannot see ahead,
     * so both rows are true as recorded and collapsing them is a display concern.
     */
    test("a chord records after the modifier that opened it", async function (assert) {
      attachCapture();
      await render(
        <template><input id="typed" aria-label="Search" /></template>
      );

      // `triggerKeyEvent` rejects a lowercase key, so this reads `C` where a
      // browser would report `c`. The case is the helper's, not the panel's.
      await triggerKeyEvent("#typed", "keydown", "Meta");
      await triggerKeyEvent("#typed", "keydown", "C", { metaKey: true });
      await triggerKeyEvent("#typed", "keydown", "Tab", { shiftKey: true });

      assert.deepEqual(
        entriesOf("event").map((entry) => entry.keys),
        [
          [appleGlyph("Meta", "\u2318")],
          [appleGlyph("Meta", "\u2318"), "C"],
          [appleGlyph("Shift", "\u21e7"), "Tab"],
        ],
        "the chord names every modifier held at the moment it was pressed"
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

      await triggerKeyEvent("#typed", "keydown", "Meta");
      await triggerKeyEvent("#typed", "keydown", "Control");

      assert.deepEqual(
        entriesOf("event").map((entry) => entry.keys),
        [[appleGlyph("Meta", "\u2318")], [appleGlyph("Control", "\u2303")]],
        "no chord claimed them, so they stand on their own"
      );

      detachCapture();
    });

    // Release stops producing rows of its own, so the two rows Tab used to make
    // become one, in causal order rather than reversed.
    test("a release does not record a row", async function (assert) {
      attachCapture();
      await render(
        <template><input id="typed" aria-label="Search" /></template>
      );

      await triggerKeyEvent("#typed", "keydown", "Tab");
      await triggerKeyEvent("#typed", "keyup", "Tab");

      assert.deepEqual(
        entriesOf("event").map((entry) => entry.label),
        ["keydown"],
        "one press is one row"
      );

      detachCapture();
    });

    /*
     * Oracle for unit 1b's remaining capture facts. These are all fields the
     * event carries and capture currently discards, so each test asserts that a
     * fact reaches the entry rather than that a rule fires on it.
     *
     * Co-located rather than given its own file because the running devserver
     * expands its test-discovery glob only at a full build, so a new file reports
     * "No tests matched" instead of running.
     */
    module("capture facts (unit 1b)", function () {
      /**
       * `triggerKeyEvent` builds the event from a key and a modifier map, so it
       * cannot express `code` or `repeat`. Dispatching directly is the only way to
       * fixture a composed character or an auto-repeat.
       */
      function pressKey(selector, init) {
        document
          .querySelector(selector)
          .dispatchEvent(
            new KeyboardEvent("keydown", { bubbles: true, ...init })
          );
        return settled();
      }

      /*
       * `key` is the produced character and `code` is the physical key, and a
       * chord needs the second: on a Mac `Option+A` composes `å`, so a shortcut
       * identified by `key` stops matching the moment a modifier composes a
       * character, and again on any non-US layout.
       */
      test("a chord records the physical key alongside the character", async function (assert) {
        attachCapture();
        await render(
          <template><input id="typed" aria-label="Search" /></template>
        );

        await pressKey("#typed", { key: "å", code: "KeyA", altKey: true });

        const [entry] = entriesOf("event");
        assert.deepEqual(
          entry.keys,
          [appleGlyph("Alt", "⌥"), "å"],
          "what was typed is the composed character"
        );
        assert.strictEqual(
          entry.code,
          "KeyA",
          "which shortcut was pressed is the physical key"
        );

        detachCapture();
      });

      test("a shifted character reports the character and not the unshifted key", async function (assert) {
        attachCapture();
        await render(
          <template><input id="typed" aria-label="Search" /></template>
        );

        await pressKey("#typed", {
          key: ":",
          code: "Semicolon",
          shiftKey: true,
        });

        const [entry] = entriesOf("event");
        assert.deepEqual(entry.keys, [appleGlyph("Shift", "⇧"), ":"]);
        assert.strictEqual(entry.code, "Semicolon");

        detachCapture();
      });

      /*
       * Churn grouping keys on the region a lifecycle row is about, and the whole
       * point of it being a field is that it is not parsed back out of a display
       * string. Every projection test builds its own entries, so without this the
       * grouping could be correct and still never fire on a real capture.
       */
      test("a lifecycle row carries the region's key as a field", async function (assert) {
        await render(<template></template>);
        attachLiveRegions();

        const host = document.createElement("div");
        host.innerHTML = `<div id="arriving" aria-live="polite"></div>`;
        document.body.appendChild(host);

        try {
          attachLiveRegions();

          const joined = timelineEntries().find(
            (entry) => entry.label === "live region joined"
          );
          assert.strictEqual(
            joined.regionKey,
            "id:arriving",
            "the identity is a field, not something to recover from the detail text"
          );
        } finally {
          host.remove();
        }
      });

      /*
       * The snapshot is deferred to a queued read, and an event object is not
       * guaranteed to still carry its properties by then. An ordinary synthetic
       * event keeps them, so nothing else in this module can tell a synchronous
       * read from a deferred one: stripping the fields between dispatch and the
       * queued read is what a recycled event looks like.
       */
      test("event facts are read at dispatch, not in the deferred read", async function (assert) {
        attachCapture();
        await render(
          <template><input id="typed" aria-label="Search" /></template>
        );

        const event = new KeyboardEvent("keydown", {
          bubbles: true,
          key: "ArrowDown",
          code: "ArrowDown",
          repeat: true,
        });
        document.querySelector("#typed").dispatchEvent(event);

        for (const field of ["key", "code", "repeat"]) {
          Object.defineProperty(event, field, {
            configurable: true,
            value: undefined,
          });
        }
        await settled();

        const [entry] = entriesOf("event");
        assert.deepEqual(
          entry.keys,
          ["ArrowDown"],
          "the chord was read while the event still carried it"
        );
        assert.strictEqual(entry.code, "ArrowDown", "and the physical key");
        assert.true(entry.repeat, "and the repeat flag");

        detachCapture();
      });

      /*
       * A lock is a state, not a key being held. `getModifierState("NumLock")` is
       * true for as long as num lock is on, and it is on by default on most
       * external keyboards, so folding locks into the chord would prefix half the
       * world's keystrokes with a modifier nobody pressed. A shortcut is `Cmd+K`,
       * never `NumLock+Cmd+K`.
       */
      test("a lock state is not part of the chord", async function (assert) {
        attachCapture();
        await render(
          <template><input id="typed" aria-label="Search" /></template>
        );

        await pressKey("#typed", {
          key: "K",
          code: "KeyK",
          metaKey: true,
          modifierCapsLock: true,
          modifierFnLock: true,
          modifierNumLock: true,
          modifierScrollLock: true,
          modifierSymbolLock: true,
        });

        assert.deepEqual(
          entriesOf("event")[0].keys,
          [appleGlyph("Meta", "⌘"), "K"],
          "only the modifiers actually held compose the chord"
        );

        detachCapture();
      });

      /*
       * One physical key can set more than one state. On Windows AltGr IS
       * Control+Alt and reports all three; on macOS Firefox reports Option as both
       * Alt and AltGraph. Reporting each true state independently turns one
       * keypress into a chord of three modifiers that were never pressed.
       */
      test("AltGraph does not double-report the modifiers it implies", async function (assert) {
        attachCapture();
        await render(
          <template><input id="typed" aria-label="Search" /></template>
        );

        await pressKey("#typed", {
          key: "Q",
          code: "KeyQ",
          altKey: true,
          ctrlKey: true,
          modifierAltGraph: true,
        });

        // No Apple keyboard prints a glyph for AltGraph, so the DOM's own name
        // is what the panel reports.
        assert.deepEqual(
          entriesOf("event")[0].keys,
          ["AltGraph", "Q"],
          "AltGraph subsumes the Alt and Control it is composed of"
        );

        detachCapture();
      });

      /*
       * Snapshots come only from captured events, so filtering auto-repeat would
       * make a held arrow key move the cursor invisibly: one row, and every
       * intermediate position gone. Capture stays lossless and marks the repeat;
       * collapsing a held run is the row grammar's job.
       */
      test("a held key records every repeat, marked as one", async function (assert) {
        attachCapture();
        await render(
          <template>
            <input
              id="typed"
              role="combobox"
              aria-label="Search"
              aria-activedescendant="o1"
            />
            <ul role="listbox" id="lb">
              <li role="option" id="o1">Bugs</li>
              <li role="option" id="o2">Feature requests</li>
              <li role="option" id="o3">Support</li>
            </ul>
          </template>
        );

        // The cursor is read from `activeElement`, not from the event's target,
        // so an unfocused input snapshots `body` and every repeat agrees at
        // "no cursor" — which would pass the count and prove nothing moved.
        await focus("#typed");

        const typed = document.querySelector("#typed");
        await pressKey("#typed", { key: "ArrowDown", code: "ArrowDown" });

        // Two repeats rather than one: an implementation that records the first
        // repeat and suppresses the rest is the plausible wrong one, and a single
        // repeat cannot tell it apart from a lossless capture.
        for (const id of ["o2", "o3"]) {
          typed.setAttribute("aria-activedescendant", id);
          await pressKey("#typed", {
            key: "ArrowDown",
            code: "ArrowDown",
            repeat: true,
          });
        }

        const presses = entriesOf("event").filter(
          (entry) => entry.label === "keydown"
        );
        assert.deepEqual(
          presses.map((entry) => Boolean(entry.repeat)),
          [false, true, true],
          "every repeat records and stays distinguishable from the first press"
        );
        assert.true(
          presses.every((entry) => Boolean(entry.snapshot)),
          "every repeat carries a snapshot"
        );
        const targets = presses.map((entry) => entry.snapshot.cursorTarget);
        assert.true(
          targets[0].includes("Bugs"),
          `the first press saw the first option, got ${targets[0]}`
        );
        assert.true(
          targets[1].includes("Feature requests"),
          `the first repeat saw the second, got ${targets[1]}`
        );
        assert.true(
          targets[2].includes("Support"),
          `the second repeat saw the third, got ${targets[2]}`
        );

        detachCapture();
      });

      /*
       * A click row read `activeElement`, so clicking anything unfocusable
       * described whatever still held focus, and a click with focus on `body`
       * produced a row with no detail at all.
       */
      test("a click names what was clicked, not what holds focus", async function (assert) {
        attachCapture();
        await render(
          <template>
            <button type="button" id="focused">Save</button>
            <span id="plain">plain text</span>
          </template>
        );

        await focus("#focused");
        await click("#plain");

        const clicked = entriesOf("event").find(
          (entry) => entry.label === "click"
        );
        assert.strictEqual(
          typeof clicked.target,
          "string",
          "the row records a target at all"
        );
        assert.true(
          clicked.target.includes("plain"),
          `the clicked element is named, got ${clicked.target}`
        );
        assert.notStrictEqual(
          clicked.target,
          clicked.snapshot.focused,
          "target and focus are different facts and the row keeps both"
        );

        detachCapture();
      });

      /*
       * A programmatic focus move and a synthetic click are their own class of
       * accessibility bug and were indistinguishable from a person. A trusted
       * event cannot be constructed from script, so only the synthetic half is
       * fixturable here.
       */
      test("a synthetic event is marked untrusted", async function (assert) {
        attachCapture();
        await render(
          <template><input id="typed" aria-label="Search" /></template>
        );

        await pressKey("#typed", { key: "ArrowDown", code: "ArrowDown" });

        assert.false(
          entriesOf("event")[0].trusted,
          "dispatched from script, so not a person"
        );

        detachCapture();
      });

      /*
       * `role="alert"` implies assertive, and the delivered row printed a literal
       * `?` for it — a hole rendered rather than named. The channel was already
       * resolved from the role for intent matching; only the label was not.
       */
      test("a delivery names the politeness the role implies", async function (assert) {
        await render(
          <template>
            <div role="alert" id="implied"></div>
          </template>
        );
        attachLiveRegions();

        document.querySelector("#implied").textContent = "saved";
        await settledAnnouncements();

        const [delivered] = entriesOf("delivered");
        assert.strictEqual(
          delivered.label,
          "delivered assertive",
          "the role supplies the channel, so nothing is unresolved"
        );
      });

      /*
       * The channel decides two things — the label on the row and which pending
       * intent the delivery closes — and they have to be the same answer. Reading
       * the label from live markup while matching on the channel cached at
       * discovery lets a row say it delivered assertively while closing a polite
       * intent, which is worse than either answer alone.
       */
      test("the delivered channel agrees with the intent it closed", async function (assert) {
        installA11yTap();
        await render(
          <template>
            <div role="status" id="drifting"></div>
          </template>
        );
        attachLiveRegions();

        // No settle between the announce and the delivery: the undelivered
        // deadline is a runloop timer, so settling here would retire the pending
        // intent and leave nothing for the delivery to close.
        this.a11y.announce("saved", "polite");

        // No captured event intervenes, so nothing rediscovers the region.
        const region = document.querySelector("#drifting");
        region.setAttribute("role", "alert");
        region.textContent = "saved";
        await settledAnnouncements();

        const [delivered] = entriesOf("delivered");
        const [intent] = entriesOf("intent");
        assert.strictEqual(
          delivered.intentSeq,
          intent.seq,
          "the delivery closed the polite intent"
        );
        assert.strictEqual(
          delivered.label,
          "delivered polite",
          "so it reports the channel it closed rather than the newer markup"
        );
      });
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

    /*
     * Timing and correlation facts (unit 0d).
     *
     * The panel computes a timestamp today purely to rate-limit the runaway
     * check and then throws it away, so no row can say when it happened or how
     * long after the row above it. That gap is diagnostic in ways nothing else
     * covers: twenty milliseconds between focus events is a script, three
     * seconds is a person, and an announcement that lands 900ms late arrives
     * after the user has moved on.
     */
    test("every entry carries a monotonic timestamp", async function (assert) {
      attachCapture();
      await render(
        <template>
          <button id="a">A</button><button id="b">B</button>
        </template>
      );
      await focus("#a");
      await focus("#b");

      const stamps = timelineEntries().map(({ at }) => at);

      assert.true(
        stamps.every((at) => typeof at === "number" && Number.isFinite(at)),
        "a row with no time cannot be placed against any other row"
      );
      assert.deepEqual(
        [...stamps].sort((a, b) => a - b),
        stamps,
        "recorded in order, so a later row never predates an earlier one"
      );
    });

    /*
     * Elapsed is frozen at record time rather than derived at render. Derived,
     * it has no basis once the ring evicts the predecessor or the timeline is
     * cleared — and `clearTimeline` keeps allocating sequence numbers, so the
     * next row still looks like it has one.
     */
    test("elapsed survives its predecessor being cleared away", async function (assert) {
      attachCapture();
      await render(
        <template>
          <button id="a">A</button><button id="b">B</button>
        </template>
      );
      await focus("#a");
      await focus("#b");

      const before = timelineEntries().at(-1).elapsedMs;
      assert.strictEqual(
        typeof before,
        "number",
        "the second row knows how long after the first it happened"
      );

      const survivor = timelineEntries().at(-1);
      clearTimeline();
      await focus("#a");

      assert.strictEqual(
        survivor.elapsedMs,
        before,
        "a recorded row does not change its mind when its neighbours go away"
      );
      assert.strictEqual(
        timelineEntries()[0].elapsedMs,
        undefined,
        "and the first row after a clear has nothing to measure against"
      );
    });

    test("an intent records the message it requested, normalised", async function (assert) {
      installA11yTap();
      await render(<template><A11yLiveRegions /></template>);
      attachLiveRegions();

      this.a11y.announce("  Draft saved  ", "polite");
      await settledAnnouncements();

      assert.strictEqual(
        entriesOf("intent").at(-1).message,
        "Draft saved",
        "trimmed the same way the service trims it, or a comparison against " +
          "the delivered text can never agree"
      );
    });

    /*
     * The pairing this unlocks. Correlation currently matches a delivery to the
     * first pending intent on the channel and keeps nothing to check it
     * against, so two announcements in one tick can be paired the wrong way
     * round and nothing would notice.
     */
    test("a delivery reports its latency from its own intent", async function (assert) {
      installA11yTap();
      await render(<template><A11yLiveRegions /></template>);
      attachLiveRegions();

      this.a11y.announce("Draft saved", "polite");
      await settledAnnouncements();

      const delivered = entriesOf("delivered").at(-1);
      const intent = entriesOf("intent").at(-1);

      assert.strictEqual(
        typeof delivered.latencyMs,
        "number",
        "the gap between asking and arriving is the announcement half's measurement"
      );
      assert.true(
        delivered.latencyMs >= 0,
        "a delivery never precedes the intent it answers"
      );
      assert.strictEqual(
        delivered.intentSeq,
        intent.seq,
        "and it names which intent it answered, rather than implying the nearest one"
      );
    });
  }
);
