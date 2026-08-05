import { click, fillIn, focus, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import A11yLiveRegions from "discourse/components/a11y/live-regions";
import {
  disableClearA11yAnnouncementsInTests,
  enableClearA11yAnnouncementsInTests,
} from "discourse/services/a11y";
import A11yButton from "discourse/static/dev-tools/a11y/button";
import {
  attachCapture,
  attachLiveRegions,
  detachCapture,
  disconnectLiveRegions,
  installA11yTap,
  resetA11yInstrumentation,
  timelineEntries,
} from "discourse/static/dev-tools/a11y/instrumentation";
import A11yPanel from "discourse/static/dev-tools/a11y/panel";
import {
  clearDockPanels,
  closeDock,
  dockState,
} from "discourse/static/dev-tools/dock";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

async function settledAnnouncements() {
  await settled();
  await Promise.resolve();
}

/**
 * Oracle for the a11y panel UI (unit A3). It exercises the panel as dock-tab
 * content against the real instrumentation: entries come from real announce
 * calls, so the rows the panel shows are the rows a session would produce.
 */
module("Integration | Component | dev-tools | a11y-panel", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.a11y = this.owner.lookup("service:a11y");
    disableClearA11yAnnouncementsInTests();
    installA11yTap();
  });

  hooks.afterEach(function () {
    resetA11yInstrumentation();
    closeDock();
    clearDockPanels();
    enableClearA11yAnnouncementsInTests();
  });

  test("the timeline lists entries oldest-first with their sequence numbers", async function (assert) {
    await render(
      <template>
        <A11yLiveRegions />
        <A11yPanel />
      </template>
    );
    attachLiveRegions();

    this.a11y.announce("first message", "polite");
    await settledAnnouncements();
    this.a11y.announce("second message", "polite");
    await settledAnnouncements();

    const rows = [...document.querySelectorAll(".dev-tools-a11y__entry")];
    assert.true(rows.length >= 2, "entries render as rows");

    const texts = rows.map((row) => row.textContent);
    assert.true(
      texts.findIndex((t) => t.includes("first message")) <
        texts.findIndex((t) => t.includes("second message")),
      "older entries come first"
    );
    assert
      .dom(rows[0].querySelector(".dev-tools-a11y__entry-seq"))
      .exists("rows carry their sequence");
  });

  // A region exists on the requested channel, but the announcement service
  // never writes into it. A repeat into a working region is NOT this case — the
  // region blanks in between, so the second write is really spoken.
  test("an intent with no delivery is flagged", async function (assert) {
    await render(
      <template>
        <div aria-live="polite"></div>
        <A11yPanel />
      </template>
    );
    attachLiveRegions();

    this.a11y.announce("no results", "polite");
    await settledAnnouncements();

    assert
      .dom(".dev-tools-a11y__entry.--event .dev-tools-a11y__not-delivered")
      .exists("the later finding carries a not-delivered marker");
  });

  test("a repeat into a working region is not flagged", async function (assert) {
    await render(
      <template>
        <A11yLiveRegions />
        <A11yPanel />
      </template>
    );
    attachLiveRegions();

    this.a11y.announce("no results", "polite");
    await settledAnnouncements();
    this.a11y.announce("no results", "polite");
    await settledAnnouncements();

    assert
      .dom(".dev-tools-a11y__not-delivered")
      .doesNotExist("both deliveries were observed");
    assert
      .dom(".dev-tools-a11y__entry.--delivered")
      .exists({ count: 2 }, "the repeat is a second spoken entry");
  });

  test("the text filter narrows the timeline", async function (assert) {
    await render(
      <template>
        <A11yLiveRegions />
        <A11yPanel />
      </template>
    );
    attachLiveRegions();

    this.a11y.announce("alpha wolf", "polite");
    await settledAnnouncements();
    this.a11y.announce("beta fish", "polite");
    await settledAnnouncements();

    await fillIn(".dev-tools-a11y__toolbar input", "alpha");

    const visible = [...document.querySelectorAll(".dev-tools-a11y__entry")]
      .map((row) => row.textContent)
      .join(" ");
    assert.true(visible.includes("alpha wolf"));
    assert.false(visible.includes("beta fish"));
  });

  // "5 live regions" cannot tell a leak from bookkeeping, so the chip has to
  // name what is behind the number.
  test("the regions chip names the regions it is counting", async function (assert) {
    await render(
      <template>
        <A11yLiveRegions />
        <A11yPanel />
      </template>
    );
    attachLiveRegions();
    await settled();

    assert
      .dom(".dev-tools-a11y__chip.--regions")
      .hasAttribute("title", /#a11y-announcements-polite \(polite\)/)
      .hasAttribute("title", /#a11y-announcements-assertive \(assertive\)/);
  });

  test("a cursor pointing outside the accessibility tree is flagged", async function (assert) {
    attachCapture();
    await render(
      <template>
        <A11yPanel />
        <input
          role="combobox"
          id="cb"
          aria-label="Category"
          aria-controls="lb"
          aria-activedescendant="row"
        />
        <ul role="listbox" id="lb" style="display: none">
          <li role="option" id="row">Bugs</li>
        </ul>
      </template>
    );

    await focus("#cb");

    // The combobox is visible; only its cursor target is not. The two must not
    // be conflated, or one defect is reported twice under two rules.
    //
    // Asserted by absence and presence rather than as the complete list: this
    // fixture is ordinary markup and will keep attracting new observations as
    // the catalogue grows, and none of those make the claim below less true.
    const recorded = timelineEntries().flatMap((entry) =>
      entry.findings.map(({ id }) => id)
    );

    assert.true(
      recorded.includes("cursor.target-hidden"),
      "the cursor target is out of the tree"
    );
    assert.false(
      recorded.includes("focus.not-in-tree"),
      "the visible focus does not inherit the cursor target's tree exclusion"
    );
    assert
      .dom(".dev-tools-a11y__timeline .dev-tools-a11y__problem")
      .exists({ count: 1 }, "one problem, and it is the one that matters");
    assert
      .dom(".dev-tools-a11y__timeline .dev-tools-a11y__problem")
      .hasText(i18n("dev_tools.a11y.findings.cursor.target_hidden"));

    detachCapture();
  });

  test("the problems toggle keeps only problem rows", async function (assert) {
    await render(
      <template>
        <A11yLiveRegions />
        <A11yPanel />
      </template>
    );
    attachLiveRegions();

    this.a11y.announce("healthy delivery", "polite");
    await settledAnnouncements();

    // Announced into a document with no watched region left, so this one has no
    // delivery to pair with and becomes the problem row the filter must keep.
    disconnectLiveRegions();
    this.a11y.announce("lost delivery", "polite");
    await settledAnnouncements();

    await click(".dev-tools-a11y__problems-toggle");

    assert.dom(".dev-tools-a11y__problems-toggle").hasAria("pressed", "true");
    const rows = [...document.querySelectorAll(".dev-tools-a11y__entry")];
    assert.true(rows.length >= 1, "problem rows remain");
    assert.true(
      rows.every((row) => row.className.includes("--")),
      "only flagged rows survive the filter"
    );
    assert.false(
      rows.some(
        (row) =>
          row.textContent.includes("healthy delivery") &&
          !row.querySelector(".dev-tools-a11y__not-delivered")
      ),
      "clean deliveries are filtered out"
    );
  });

  test("pause is a pressed toggle that stops new rows", async function (assert) {
    await render(
      <template>
        <A11yLiveRegions />
        <A11yPanel />
      </template>
    );
    attachLiveRegions();

    await click(".dev-tools-a11y__pause");
    assert.dom(".dev-tools-a11y__pause").hasAria("pressed", "true");

    this.a11y.announce("while paused", "polite");
    await settledAnnouncements();
    assert.dom(".dev-tools-a11y__entry").doesNotExist();

    await click(".dev-tools-a11y__pause");
    this.a11y.announce("after resume", "polite");
    await settledAnnouncements();
    assert.dom(".dev-tools-a11y__entry").exists();
  });

  test("clear empties the timeline without a dialog", async function (assert) {
    await render(
      <template>
        <A11yLiveRegions />
        <A11yPanel />
      </template>
    );
    attachLiveRegions();

    this.a11y.announce("something", "polite");
    await settledAnnouncements();
    assert.dom(".dev-tools-a11y__entry").exists();

    await click(".dev-tools-a11y__clear");
    assert.dom(".dev-tools-a11y__entry").doesNotExist();
    assert
      .dom(".dialog-container")
      .doesNotExist("clearing is part of the repro loop, never confirmed");
  });

  test("the test-channel control proves the whole pipe", async function (assert) {
    await render(
      <template>
        <A11yLiveRegions />
        <A11yPanel />
      </template>
    );
    attachLiveRegions();

    await click(".dev-tools-a11y__test-channel");
    await click(".dev-tools-a11y__test-polite");
    await settledAnnouncements();

    assert.dom(".dev-tools-a11y__entry.--intent").exists("intent recorded");
    assert
      .dom(".dev-tools-a11y__entry.--delivered")
      .exists("delivery recorded");
    assert
      .dom(".dev-tools-a11y__entry.--event")
      .doesNotExist("choosing from the menu never enters the trace");
  });

  test("the test channel can exercise the assertive path", async function (assert) {
    await render(
      <template>
        <A11yLiveRegions />
        <A11yPanel />
      </template>
    );
    attachLiveRegions();

    await click(".dev-tools-a11y__test-channel");
    await click(".dev-tools-a11y__test-assertive");
    await settledAnnouncements();

    const rows = [...document.querySelectorAll(".dev-tools-a11y__entry")]
      .map((row) => row.textContent)
      .join(" ");
    assert.true(
      rows.includes("politeness=assertive"),
      "the intent carries the assertive politeness"
    );
    assert.true(
      rows.includes("a11y-announcements-assertive"),
      "delivery came from the assertive region"
    );
  });

  test("the regions chip warns loudly at zero", async function (assert) {
    await render(<template><A11yPanel /></template>);
    attachLiveRegions();
    await settled();

    assert
      .dom(".dev-tools-a11y__chip.--regions.--critical")
      .exists("zero regions is a critical chip");
    assert.dom(".dev-tools-a11y__warning").exists("and a banner");
    assert
      .dom(".dev-tools-a11y__warning[role='alert']")
      .doesNotExist("the banner must not be a live region the panel watches");
  });

  test("an empty timeline guides the user instead of showing nothing", async function (assert) {
    await render(
      <template>
        <A11yLiveRegions />
        <A11yPanel />
      </template>
    );

    assert.dom(".dev-tools-a11y__empty").exists();
  });

  test("the inspector view renders the grouped snapshot", async function (assert) {
    await render(
      <template>
        <A11yLiveRegions />
        <A11yPanel />
      </template>
    );

    await click(".dev-tools-a11y__view.--inspector");

    assert
      .dom(".dev-tools-a11y__inspector")
      .exists("the inspector view renders");
    assert
      .dom(".dev-tools-a11y__no-snapshot")
      .exists("without an interaction it says so");
  });

  test("panel controls never enter the trace", async function (assert) {
    await render(
      <template>
        <div class="dev-tools-toolbar">
          <A11yLiveRegions />
          <A11yPanel />
        </div>
      </template>
    );
    attachLiveRegions();

    await click(".dev-tools-a11y__pause");
    await click(".dev-tools-a11y__pause");

    assert
      .dom(".dev-tools-a11y__entry.--event")
      .doesNotExist("interacting with the panel records no events");
  });

  test("the toolbar button toggles the a11y dock tool", async function (assert) {
    await render(<template><A11yButton /></template>);

    await click(".toggle-a11y");
    assert.true(dockState().open);
    assert.strictEqual(dockState().activeTool, "a11y");
    assert.dom(".toggle-a11y").hasClass("--active");

    await click(".toggle-a11y");
    assert.false(dockState().open);
  });
});
