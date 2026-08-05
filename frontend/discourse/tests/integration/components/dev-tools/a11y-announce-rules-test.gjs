import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import A11yLiveRegions from "discourse/components/a11y/live-regions";
import {
  disableClearA11yAnnouncementsInTests,
  enableClearA11yAnnouncementsInTests,
} from "discourse/services/a11y";
// Namespace import on purpose: a named import of something not yet exported
// fails at link time and takes the whole module down, which reads as a broken
// suite rather than as an assertion failing.
import * as instrumentation from "discourse/static/dev-tools/a11y/instrumentation";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

/**
 * Oracle for announcement correlation (unit 3b).
 *
 * An intent and a delivery are different things, and the whole value of this
 * half of the panel is in the gap between them. `announce()` was called; did
 * anything actually reach a region, on the channel that was asked for, in a
 * region a reader could see? Every rule below is one way that pairing fails.
 *
 * The governing constraint, and the reason the previous version of this panel
 * was useless: a live-region rule fires only when an announcement was actually
 * attempted. A populated region sitting there for future updates, a hidden
 * region reserved for later, and a page with no regions at all are all normal,
 * and reporting them is how a tool teaches people to ignore it.
 */
module(
  "Integration | Component | dev-tools | a11y-announce-rules",
  function (hooks) {
    setupRenderingTest(hooks);

    let fixtures;

    hooks.beforeEach(function () {
      fixtures = [];
      this.a11y = this.owner.lookup("service:a11y");
      disableClearA11yAnnouncementsInTests();
      instrumentation.installA11yTap();
    });

    hooks.afterEach(function () {
      fixtures.forEach((fixture) => fixture.remove());
      instrumentation.resetA11yInstrumentation();
      enableClearA11yAnnouncementsInTests();
    });

    // MutationObserver callbacks are microtasks settled() does not cover, and
    // the undelivered deadline is a runloop timer that it does.
    async function settledAnnouncements() {
      await settled();
      await Promise.resolve();
      await settled();
    }

    function addFixture(html) {
      const host = document.createElement("div");
      host.innerHTML = html;
      document.body.appendChild(host);
      fixtures.push(host);

      return host;
    }

    /** Every finding id anywhere in the timeline. */
    function findingIds() {
      return instrumentation
        .timelineEntries()
        .flatMap((entry) => entry.findings.map(({ id }) => id));
    }

    test("announcing with nowhere to land is a defect", async function (assert) {
      await render(
        <template>
          {{! no live regions }}
        </template>
      );
      instrumentation.attachLiveRegions();

      this.a11y.announce("no results", "polite");
      await settledAnnouncements();

      assert.true(
        findingIds().includes("announce.no-region"),
        "the intent had no region on its channel"
      );
    });

    // A verdict about one intent belongs to that intent's row. Given its own
    // row it doubles the timeline, and the ring that keeps the newest 200
    // entries then holds 100 announcements instead of 200.
    test("a verdict about an intent rides on the intent, not a second row", async function (assert) {
      await render(
        <template>
          {{! no live regions }}
        </template>
      );
      instrumentation.attachLiveRegions();

      const before = instrumentation.timelineEntries().length;
      this.a11y.announce("no results", "polite");
      await settled();

      const added = instrumentation.timelineEntries().slice(before);

      assert.strictEqual(added.length, 1, "one announcement, one row");
      assert.strictEqual(added[0].kind, "intent");
      assert.true(
        added[0].findings.some(({ id }) => id === "announce.no-region"),
        "and the verdict is on it"
      );
    });

    test("announcing into a region the reader cannot see is a defect", async function (assert) {
      const host = addFixture(
        `<div style="display: none"><div id="a11y-announcements-polite" role="status" aria-live="polite"></div></div>`
      );
      instrumentation.attachLiveRegions();

      this.a11y.announce("twelve results", "polite");
      await settledAnnouncements();

      assert.true(
        findingIds().includes("live.not-in-tree"),
        "the region exists, the announcement is still dropped"
      );
      assert.true(Boolean(host), "fixture retained for teardown");
    });

    // The governing principle, stated as a test. A region holding text is the
    // normal resting state of a region that has ever been used.
    test("a populated region nobody announced into is not a defect", async function (assert) {
      addFixture(`<div aria-live="polite">seven results</div>`);
      await render(<template><A11yLiveRegions /></template>);
      instrumentation.attachLiveRegions();
      await settledAnnouncements();

      assert.false(
        findingIds().includes("live.born-with-content"),
        "state alone is not a defect"
      );
    });

    // Readers fire on a text CHANGE in a region they were already tracking. A
    // region inserted with its message already in it never changes, so the
    // reader has nothing to notice and the message is silent.
    test("a region that arrives already holding its message is a defect", async function (assert) {
      await render(<template><A11yLiveRegions /></template>);
      instrumentation.attachLiveRegions();

      addFixture(`<div aria-live="polite">seven results</div>`);
      this.a11y.announce("seven results", "polite");
      await settledAnnouncements();

      assert.true(
        findingIds().includes("live.born-with-content"),
        "inserted with its content, correlated with a real intent"
      );
    });

    // Reader tracking binds to the element. A region destroyed and recreated is
    // a new element the reader is not watching, so anything written in the same
    // tick is missed — and nothing about the DOM afterwards looks wrong.
    test("a region replaced after it has delivered is a defect", async function (assert) {
      // Its own region, not a rendered one: replacing a node the renderer owns
      // makes teardown throw and aborts the run instead of failing the test.
      const host = addFixture(
        `<div id="replaceable-region" aria-live="polite"></div>`
      );
      instrumentation.attachLiveRegions();

      host.querySelector("#replaceable-region").textContent = "first message";
      await settledAnnouncements();

      const original = host.querySelector("#replaceable-region");
      const replacement = original.cloneNode(true);
      original.replaceWith(replacement);

      instrumentation.attachLiveRegions();
      await settledAnnouncements();

      assert.true(
        findingIds().includes("live.replaced-mid-session"),
        "the same region, a different element, after it had already delivered"
      );
    });

    // A caller repeating one identical string many times per second is looping,
    // not informing. The counterweight is that repeats are legitimate and must
    // stay legitimate: a changing message is a working feature, however fast.
    test("the same message over and over is a runaway", async function (assert) {
      await render(<template><A11yLiveRegions /></template>);
      instrumentation.attachLiveRegions();

      for (let index = 0; index < 12; index++) {
        this.a11y.announce("still loading", "polite");
      }
      await settledAnnouncements();

      assert.true(
        findingIds().includes("announce.runaway"),
        "twelve identical messages in one tick is a loop"
      );
    });

    test("a message that changes is never a runaway, however fast", async function (assert) {
      await render(<template><A11yLiveRegions /></template>);
      instrumentation.attachLiveRegions();

      for (let index = 0; index < 12; index++) {
        this.a11y.announce(`${index + 1} new messages`, "polite");
      }
      await settledAnnouncements();

      assert.false(
        findingIds().includes("announce.runaway"),
        "a counter that climbs is a feature working, not a caller looping"
      );
    });

    // The panel observes a DOM write. Saying an intent went undelivered is a
    // claim about a deadline having passed, which cannot be known when the
    // intent is recorded — so it is its own later row rather than a verdict
    // retro-fitted onto a frozen entry.
    // A region on the channel exists and is watched, but nothing renders into
    // it, so the write never comes. That is the whole distinction from
    // `announce.no-region`: having nowhere to land and landing nowhere are
    // different defects with different fixes, and reporting both for one
    // announcement says the same thing twice.
    test("an intent that never arrives is reported once the deadline passes", async function (assert) {
      addFixture(`<div id="silent-region" aria-live="polite"></div>`);
      instrumentation.attachLiveRegions();

      this.a11y.announce("no results", "polite");
      await settledAnnouncements();

      assert.true(
        findingIds().includes("announce.undelivered"),
        "a region was there to write to, and nothing wrote to it"
      );
      assert.false(
        findingIds().includes("announce.no-region"),
        "and it is not also reported as having nowhere to go"
      );
    });

    test("an intent that arrives is not reported as undelivered", async function (assert) {
      await render(<template><A11yLiveRegions /></template>);
      instrumentation.attachLiveRegions();

      this.a11y.announce("twelve results", "polite");
      await settledAnnouncements();

      assert.false(
        findingIds().includes("announce.undelivered"),
        "a working announcement is silent"
      );
      assert.false(
        findingIds().includes("announce.no-region"),
        "and it had somewhere to land"
      );
    });

    // The zero-noise gate for this half: the ordinary working case raises
    // nothing that ranks, on a page carrying the product's real regions.
    test("an ordinary announcement raises nothing that ranks", async function (assert) {
      await render(<template><A11yLiveRegions /></template>);
      instrumentation.attachLiveRegions();

      this.a11y.announce("twelve results", "polite");
      await settledAnnouncements();

      const ranked = instrumentation
        .timelineEntries()
        .flatMap((entry) => entry.findings)
        .filter(({ tier }) => tier === "broken");

      assert.deepEqual(
        ranked.map(({ id }) => id),
        [],
        "nothing to report"
      );
    });
  }
);
