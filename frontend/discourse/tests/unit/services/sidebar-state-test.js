import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { MAIN_PANEL } from "discourse/lib/sidebar/panels";

module("Unit | Service | sidebar-state", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.sidebarState = getOwner(this).lookup("service:sidebar-state");
  });

  test("shows the panel that was asked for", function (assert) {
    this.sidebarState.setPanel("chat");
    assert.strictEqual(this.sidebarState.currentPanelKey, "chat");

    this.sidebarState.setCombinedMode();
    assert.strictEqual(this.sidebarState.currentPanelKey, MAIN_PANEL);
    assert.true(this.sidebarState.combinedMode);
  });

  test("the sidebar-panel transformer can show another panel", function (assert) {
    withPluginApi((api) => {
      api.registerValueTransformer("sidebar-panel", ({ value }) =>
        value === MAIN_PANEL || value === "chat" ? "custom" : value
      );
    });

    this.sidebarState.setPanel("chat");
    assert.strictEqual(this.sidebarState.currentPanelKey, "custom");

    this.sidebarState.setPanel("admin");
    assert.strictEqual(
      this.sidebarState.currentPanelKey,
      "admin",
      "panels the transformer leaves alone still show"
    );
  });

  test("a transformed panel isn't combined, and has no switch buttons", function (assert) {
    withPluginApi((api) => {
      api.registerValueTransformer("sidebar-panel", () => "custom");
    });

    this.sidebarState.setCombinedMode();
    assert.strictEqual(this.sidebarState.currentPanelKey, "custom");
    assert.false(this.sidebarState.combinedMode);

    this.sidebarState.showSwitchPanelButtons();
    assert.false(this.sidebarState.displaySwitchPanelButtons);
  });

  test("the transformer is told which panel was asked for", function (assert) {
    let requested;
    withPluginApi((api) => {
      api.registerValueTransformer("sidebar-panel", ({ value, context }) => {
        requested = context.requestedPanelKey;
        return value;
      });
    });

    this.sidebarState.setPanel("chat");
    assert.strictEqual(this.sidebarState.currentPanelKey, "chat");
    assert.strictEqual(requested, "chat");

    this.sidebarState.setCombinedMode();
    this.sidebarState.showSwitchPanelButtons();
    assert.true(
      this.sidebarState.combinedMode,
      "a panel left as asked keeps its mode"
    );
    assert.true(this.sidebarState.displaySwitchPanelButtons);
  });
});
