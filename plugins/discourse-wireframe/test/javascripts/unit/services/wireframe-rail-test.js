import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

const PANEL_KEY = "wireframe_leftPanelTab";
const LEFT_WIDTH_KEY = "wireframe_leftPanelWidth";
const RIGHT_COLLAPSED_KEY = "wireframe_rightCollapsed";
const LEFT_VAR = "--wf-left-panel";
const RIGHT_VAR = "--wf-right-rail";

const leftVar = () => document.body.style.getPropertyValue(LEFT_VAR);
const rightVar = () => document.body.style.getPropertyValue(RIGHT_VAR);

module("Unit | Discourse Wireframe | service:wireframe-rail", function (hooks) {
  setupTest(hooks);

  // The width setters write inline CSS vars on document.body; clear them between
  // tests so one test's width doesn't leak into the next.
  hooks.afterEach(function () {
    document.body.style.removeProperty(LEFT_VAR);
    document.body.style.removeProperty(RIGHT_VAR);
  });

  // The rail reads its persisted state through core's `keyValueStore`; seed the
  // same service so the rail (which shares this owner's instance) sees it. The
  // harness clears localStorage after every test, so no teardown is needed.

  test("defaults to the palette panel when nothing is stored", function (assert) {
    const rail = this.owner.lookup("service:wireframe-rail");
    assert.strictEqual(rail.leftPanelTab, "palette");
  });

  test("reads the persisted active panel at construction", function (assert) {
    this.owner
      .lookup("service:key-value-store")
      .setObject({ key: PANEL_KEY, value: "outline" });
    const rail = this.owner.lookup("service:wireframe-rail");
    assert.strictEqual(rail.leftPanelTab, "outline");
  });

  test("falls back to palette for an unknown stored panel", function (assert) {
    this.owner
      .lookup("service:key-value-store")
      .setObject({ key: PANEL_KEY, value: "bogus" });
    const rail = this.owner.lookup("service:wireframe-rail");
    assert.strictEqual(rail.leftPanelTab, "palette");
  });

  test("setLeftPanelTab switches the panel and persists", function (assert) {
    const rail = this.owner.lookup("service:wireframe-rail");

    rail.setLeftPanelTab("outline");
    assert.strictEqual(rail.leftPanelTab, "outline");
    assert.strictEqual(
      this.owner.lookup("service:key-value-store").getObject(PANEL_KEY),
      "outline"
    );
  });

  test("showPalette switches to the palette from another panel", function (assert) {
    const rail = this.owner.lookup("service:wireframe-rail");
    rail.setLeftPanelTab("outline");

    rail.showPalette();
    assert.strictEqual(rail.leftPanelTab, "palette");
    assert.strictEqual(
      this.owner.lookup("service:key-value-store").getObject(PANEL_KEY),
      "palette",
      "the palette becomes the remembered panel"
    );
  });

  test("defaults to the seed widths and clamps stored values on hydration", function (assert) {
    const kv = this.owner.lookup("service:key-value-store");
    kv.setObject({ key: LEFT_WIDTH_KEY, value: 9999 });
    const rail = this.owner.lookup("service:wireframe-rail");
    assert.strictEqual(
      rail.leftPanelWidth,
      rail.leftPanelMax,
      "an over-max stored width clamps to the max on read"
    );
    assert.strictEqual(
      rail.rightRailWidth,
      300,
      "an unset width falls back to the default"
    );
  });

  test("setLeftPanelWidth clamps, applies the CSS var, and persists on commit", function (assert) {
    const rail = this.owner.lookup("service:wireframe-rail");

    rail.setLeftPanelWidth(400, { commit: true });
    assert.strictEqual(rail.leftPanelWidth, 400);
    assert.strictEqual(leftVar(), "400px", "applies the width var to the body");
    assert.strictEqual(
      this.owner.lookup("service:key-value-store").getObject(LEFT_WIDTH_KEY),
      400,
      "a committed width persists"
    );

    rail.setLeftPanelWidth(99999);
    assert.strictEqual(
      rail.leftPanelWidth,
      rail.leftPanelMax,
      "clamps to the max"
    );

    rail.setLeftPanelWidth(1);
    assert.strictEqual(
      rail.leftPanelWidth,
      rail.leftPanelMin,
      "clamps to the min"
    );
  });

  test("applyRailWidths always applies the left width", function (assert) {
    const rail = this.owner.lookup("service:wireframe-rail");
    rail.setLeftPanelWidth(360);
    document.body.style.removeProperty(LEFT_VAR);

    rail.applyRailWidths();
    assert.strictEqual(
      leftVar(),
      "360px",
      "the left panel has no collapsed state to withhold its width for"
    );
  });

  test("nudge steps the width and commits", function (assert) {
    const rail = this.owner.lookup("service:wireframe-rail");
    rail.setLeftPanelWidth(300, { commit: true });
    rail.nudgeLeftPanelWidth(16);
    assert.strictEqual(rail.leftPanelWidth, 316);
    assert.strictEqual(
      this.owner.lookup("service:key-value-store").getObject(LEFT_WIDTH_KEY),
      316,
      "a nudge persists"
    );
  });

  test("right-rail collapse lives on the service and toggles its width var", function (assert) {
    const rail = this.owner.lookup("service:wireframe-rail");
    rail.setRightRailWidth(360);
    assert.false(rail.rightCollapsed, "starts expanded");
    assert.strictEqual(rightVar(), "360px");

    rail.toggleRightCollapsed();
    assert.true(rail.rightCollapsed);
    assert.strictEqual(rightVar(), "", "collapsing clears the right width var");
    assert.true(
      this.owner
        .lookup("service:key-value-store")
        .getObject(RIGHT_COLLAPSED_KEY),
      "right collapse persists"
    );

    rail.toggleRightCollapsed();
    assert.false(rail.rightCollapsed);
    assert.strictEqual(
      rightVar(),
      "360px",
      "expanding restores the persisted width"
    );
  });
});
