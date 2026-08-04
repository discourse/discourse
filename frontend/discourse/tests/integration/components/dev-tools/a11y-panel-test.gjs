import { click, fillIn, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import A11yLiveRegions from "discourse/components/a11y/live-regions";
import {
  disableClearA11yAnnouncementsInTests,
  enableClearA11yAnnouncementsInTests,
} from "discourse/services/a11y";
import A11yButton from "discourse/static/dev-tools/a11y/button";
import {
  installA11yTap,
  observeLiveRegions,
  resetA11yInstrumentation,
} from "discourse/static/dev-tools/a11y/instrumentation";
import A11yPanel from "discourse/static/dev-tools/a11y/panel";
import {
  clearDockPanels,
  closeDock,
  dockState,
} from "discourse/static/dev-tools/dock";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

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
    observeLiveRegions();

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

  test("an undelivered repeat is flagged, not hidden", async function (assert) {
    await render(
      <template>
        <A11yLiveRegions />
        <A11yPanel />
      </template>
    );
    observeLiveRegions();

    this.a11y.announce("no results", "polite");
    await settledAnnouncements();
    this.a11y.announce("no results", "polite");
    await settledAnnouncements();

    assert
      .dom(".dev-tools-a11y__entry.--intent .dev-tools-a11y__not-delivered")
      .exists("the second intent carries a not-delivered marker");
  });

  test("the text filter narrows the timeline", async function (assert) {
    await render(
      <template>
        <A11yLiveRegions />
        <A11yPanel />
      </template>
    );
    observeLiveRegions();

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

  test("the problems toggle keeps only problem rows", async function (assert) {
    await render(
      <template>
        <A11yLiveRegions />
        <A11yPanel />
      </template>
    );
    observeLiveRegions();

    this.a11y.announce("healthy delivery", "polite");
    await settledAnnouncements();
    this.a11y.announce("healthy delivery", "polite");
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
    observeLiveRegions();

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
    observeLiveRegions();

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
    observeLiveRegions();

    await click(".dev-tools-a11y__test-channel");
    await settledAnnouncements();

    assert.dom(".dev-tools-a11y__entry.--intent").exists("intent recorded");
    assert.dom(".dev-tools-a11y__entry.--spoken").exists("delivery recorded");
  });

  test("the regions chip warns loudly at zero", async function (assert) {
    await render(<template><A11yPanel /></template>);
    observeLiveRegions();
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
    observeLiveRegions();

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
