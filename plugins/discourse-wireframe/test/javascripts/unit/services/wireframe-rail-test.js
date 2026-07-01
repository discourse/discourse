import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

const PANEL_KEY = "wireframe_leftPanelTab";

module("Unit | Discourse Wireframe | service:wireframe-rail", function (hooks) {
  setupTest(hooks);

  // The rail reads its persisted state through core's `keyValueStore`; seed the
  // same service so the rail (which shares this owner's instance) sees it. The
  // harness clears localStorage after every test, so no teardown is needed.

  test("defaults to the palette panel when nothing is stored", function (assert) {
    const rail = this.owner.lookup("service:wireframe-rail");
    assert.strictEqual(rail.leftPanelTab, "palette");
    assert.false(rail.leftCollapsed);
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

  test("setLeftPanelTab switches the panel, expands, and persists", function (assert) {
    const rail = this.owner.lookup("service:wireframe-rail");
    rail.toggleLeftCollapsed();
    assert.true(rail.leftCollapsed, "starts collapsed");

    rail.setLeftPanelTab("outline");
    assert.strictEqual(rail.leftPanelTab, "outline");
    assert.false(rail.leftCollapsed, "expands the rail");
    assert.strictEqual(
      this.owner.lookup("service:key-value-store").getObject(PANEL_KEY),
      "outline"
    );
  });

  test("activatePanel toggles: re-activating the open panel collapses it", function (assert) {
    const rail = this.owner.lookup("service:wireframe-rail");

    rail.activatePanel("outline");
    assert.true(rail.isPanelOpen("outline"), "opens the chosen panel");
    assert.false(rail.isPanelOpen("palette"), "other panels read closed");

    rail.activatePanel("outline");
    assert.true(rail.leftCollapsed, "re-activating collapses");
    assert.false(
      rail.isPanelOpen("outline"),
      "no panel is open while collapsed"
    );
    assert.strictEqual(
      rail.leftPanelTab,
      "outline",
      "the active panel is remembered across collapse"
    );

    rail.activatePanel("palette");
    assert.true(rail.isPanelOpen("palette"), "activating another expands it");
    assert.false(rail.leftCollapsed);
  });

  test("showPalette reveals the palette from a collapsed outline state", function (assert) {
    const rail = this.owner.lookup("service:wireframe-rail");
    rail.activatePanel("outline");
    rail.toggleLeftCollapsed();
    assert.true(rail.leftCollapsed);

    rail.showPalette();
    assert.strictEqual(rail.leftPanelTab, "palette");
    assert.false(rail.leftCollapsed);
  });
});
