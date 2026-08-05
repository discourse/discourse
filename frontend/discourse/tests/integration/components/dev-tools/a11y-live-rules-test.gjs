import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import A11yLiveRegions from "discourse/components/a11y/live-regions";
import {
  disableClearA11yAnnouncementsInTests,
  enableClearA11yAnnouncementsInTests,
} from "discourse/services/a11y";
import { tierOf } from "discourse/static/dev-tools/a11y/findings";
// Namespace import on purpose: a named import of something not yet exported
// fails at link time and takes the whole module down, which reads as a broken
// suite rather than as the assertion below failing.
import * as instrumentation from "discourse/static/dev-tools/a11y/instrumentation";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

/**
 * Oracle for the live-region markup rules (unit 3a).
 *
 * These are the rules that pay for the panel. A region whose role and
 * `aria-live` disagree is announced on the channel the attribute names, not the
 * one the role implies, so an author who wrote "alert" ships a message the user
 * hears whenever the queue gets round to it. Nothing in the repo catches that:
 * the ARIA template lint rules check whether an attribute is valid on a role,
 * never whether two valid attributes contradict each other.
 *
 * The counterweight is that the same pairing is also the single most common
 * piece of belt-and-braces live-region markup in the wild, including in this
 * product's own shared regions. A rule that cannot tell a contradiction from a
 * redundancy would flag every one of them, and a filter where everything is
 * flagged ranks nothing. That distinction is what most of these tests are for.
 */
module(
  "Integration | Component | dev-tools | a11y-live-rules",
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

    // Outside the render root so a re-render cannot take it away mid-test.
    function addRegion(attributes) {
      const host = document.createElement("div");
      host.innerHTML = `<div id="live-fixture" ${attributes}></div>`;
      document.body.appendChild(host);
      fixtures.push(host);

      return host;
    }

    /**
     * What the rules concluded about the regions being watched.
     *
     * Deliberately not the timeline. A verdict about a region's markup belongs
     * to the region, which persists; a timeline row is an event, and a page
     * simply rendering correct markup is not an event. Reading these off the
     * timeline is what put two rows on every page in the product before the
     * user had done anything.
     */
    function regionFindings() {
      return (instrumentation.liveRegionFindings?.() ?? []).map(({ id }) => id);
    }

    /** Every finding id that reached the timeline as its own row. */
    function rowedFindings() {
      return instrumentation
        .timelineEntries()
        .flatMap((entry) => entry.findings.map(({ id }) => id));
    }

    // A region's verdict has to be reachable without going through the
    // timeline, because most verdicts must never become timeline rows.
    test("what the rules concluded about a region can be asked for directly", function (assert) {
      assert.strictEqual(
        typeof instrumentation.liveRegionFindings,
        "function",
        "region verdicts have their own accessor"
      );
    });

    test("a role and an aria-live that contradict each other are a defect", function (assert) {
      addRegion(`role="alert" aria-live="polite"`);
      instrumentation.attachLiveRegions();

      assert.true(
        regionFindings().includes("live.politeness-contradicts-role"),
        "the author wrote alert and the user gets a queued announcement"
      );
      assert.strictEqual(
        tierOf("live.politeness-contradicts-role"),
        "broken",
        "and it ranks as one"
      );
    });

    test("the contradiction is caught in the other direction too", function (assert) {
      addRegion(`role="status" aria-live="assertive"`);
      instrumentation.attachLiveRegions();

      assert.true(
        regionFindings().includes("live.politeness-contradicts-role"),
        "status announced assertively interrupts what the user was hearing"
      );
    });

    // The distinction the whole rule rests on. Same two attributes, agreeing.
    test("a role and an aria-live that agree are noted, not flagged", function (assert) {
      addRegion(`role="status" aria-live="polite"`);
      instrumentation.attachLiveRegions();

      const findings = regionFindings();

      assert.true(
        findings.includes("live.redundant-politeness"),
        "worth seeing, because each extra permutation is one more thing to go wrong"
      );
      assert.false(
        findings.includes("live.politeness-contradicts-role"),
        "but it is not a contradiction"
      );
      assert.strictEqual(
        tierOf("live.redundant-politeness"),
        "noted",
        "so it never reaches the problems filter"
      );
    });

    test("a role on its own says nothing to disagree with", function (assert) {
      addRegion(`role="alert"`);
      instrumentation.attachLiveRegions();

      assert.deepEqual(regionFindings(), [], "correct markup is quiet");
    });

    test("an aria-live on its own says nothing to disagree with", function (assert) {
      addRegion(`aria-live="polite"`);
      instrumentation.attachLiveRegions();

      assert.deepEqual(regionFindings(), [], "correct markup is quiet");
    });

    // The zero-noise gate in miniature. The product's own shared regions carry a
    // role and a matching aria-live, so a rule that got this wrong would report a
    // defect on every page in the product before finding a single real one.
    test("the product's own live regions raise nothing that ranks", async function (assert) {
      await render(<template><A11yLiveRegions /></template>);
      instrumentation.attachLiveRegions();

      const ranked = instrumentation
        .timelineEntries()
        .flatMap((entry) => entry.findings)
        .filter(({ tier }) => tier === "broken");

      assert.deepEqual(
        ranked.map(({ id }) => id),
        [],
        "nothing the shared regions do is a defect"
      );
    });

    /*
     * The regression this design was corrected by. Recording every region
     * verdict as a timeline row put two rows on every page in the product
     * before the user had touched anything, because the shared regions each
     * earn a NOTED redundancy. That broke three existing tests outright — the
     * empty-state row, and both pause tests, all of which are entitled to
     * assume an untouched page has an empty timeline.
     *
     * A row is an event. Correct markup sitting there is not one.
     */
    test("markup that is merely worth noting earns no timeline row", async function (assert) {
      addRegion(`role="status" aria-live="polite"`);
      await render(<template><A11yLiveRegions /></template>);
      instrumentation.attachLiveRegions();

      assert.true(
        regionFindings().includes("live.redundant-politeness"),
        "the verdict is still reached"
      );
      assert.deepEqual(
        rowedFindings(),
        [],
        "and it is not news, so it is not a row"
      );
      assert.strictEqual(
        instrumentation.timelineEntries().length,
        0,
        "an untouched page still has an empty timeline"
      );
    });

    // A region that was already there when watching began is not thereby correct.
    test("a region present from the start is checked like any other", function (assert) {
      addRegion(`role="alert" aria-live="polite"`);
      instrumentation.attachLiveRegions();
      instrumentation.attachLiveRegions();

      const contradictions = regionFindings().filter(
        (id) => id === "live.politeness-contradicts-role"
      );

      assert.true(contradictions.length > 0, "being first is not an exemption");
      // Watching is re-run after every captured event, so a rule that reports
      // on each pass rather than on arrival buries the timeline in copies of
      // one defect — which is the noise this panel was rebuilt to remove.
      assert.strictEqual(
        contradictions.length,
        1,
        "and a region is judged when it arrives, not on every pass"
      );
    });

    // A MutationObserver seeing text change is evidence a region was written to.
    // It is not evidence any assistive technology said anything, and the panel
    // must not claim otherwise — the distinction matters precisely when someone
    // is using this to work out why they heard nothing.
    test("a delivery is recorded as a delivery, never as speech", async function (assert) {
      await render(<template><A11yLiveRegions /></template>);
      instrumentation.attachLiveRegions();

      this.a11y.announce("twelve results", "polite");
      await settled();
      await Promise.resolve();

      const kinds = instrumentation
        .timelineEntries()
        .map((entry) => entry.kind);

      assert.true(kinds.includes("delivered"), "the DOM write is a delivery");
      assert.false(kinds.includes("spoken"), "nothing claims it was spoken");
    });
  }
);
