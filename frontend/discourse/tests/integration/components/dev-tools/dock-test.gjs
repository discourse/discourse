import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import {
  activateDockTool,
  clearDockPanels,
  closeDock,
  dockPanels,
  dockState,
  registerDockPanel,
  toggleDockTool,
} from "discourse/static/dev-tools/dock";
import DevToolsDockHost from "discourse/static/dev-tools/dock-host";
import devToolsState from "discourse/static/dev-tools/state";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

const ProbePanel = <template>
  <div data-test-dock-panel="probe">probe panel</div>
</template>;

const OtherPanel = <template>
  <div data-test-dock-panel="other">other panel</div>
</template>;

/**
 * Oracle for the dev-tools dock glue (unit U5): the panel registry, the
 * dock's open/active state in the shared flags bag, and the host component
 * that projects both into a DPanelDock with the dev-tools context.
 */
module("Integration | Component | dev-tools | dock", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    closeDock();
    clearDockPanels();
  });

  test("a registered panel becomes a dev-tools dock tab", async function (assert) {
    registerDockPanel("probe", { label: "Probe", component: ProbePanel });
    activateDockTool("probe");

    await render(<template><DevToolsDockHost /></template>);

    assert
      .dom(".d-panel-dock.--context-dev-tools")
      .exists("the dock carries the dev-tools context");
    assert
      .dom("[data-test-dock-panel='probe']")
      .exists("the active tool's panel renders");
  });

  test("the host renders nothing while the dock is closed", async function (assert) {
    registerDockPanel("probe", { label: "Probe", component: ProbePanel });

    await render(<template><DevToolsDockHost /></template>);

    assert.dom(".d-panel-dock").doesNotExist();
  });

  test("toggling walks through open, switch, and close", async function (assert) {
    registerDockPanel("probe", { label: "Probe", component: ProbePanel });
    registerDockPanel("other", { label: "Other", component: OtherPanel });

    await render(<template><DevToolsDockHost /></template>);

    toggleDockTool("probe");
    await settled();
    assert.dom("[data-test-dock-panel='probe']").exists("first toggle opens");

    toggleDockTool("other");
    await settled();
    assert
      .dom("[data-test-dock-panel='other']")
      .exists("toggling another tool switches tabs");
    assert.dom("[data-test-dock-panel='probe']").doesNotExist();

    toggleDockTool("other");
    await settled();
    assert
      .dom(".d-panel-dock")
      .doesNotExist("toggling the active tool closes the dock");
  });

  test("dock state lives in the shared flags bag", function (assert) {
    registerDockPanel("probe", { label: "Probe", component: ProbePanel });
    activateDockTool("probe");

    assert.true(devToolsState.getFlag("dock", "open"));
    assert.strictEqual(devToolsState.getFlag("dock", "activeTool"), "probe");
    assert.deepEqual(dockState(), { open: true, activeTool: "probe" });
  });

  test("activating a tab in the dock reports back into state", async function (assert) {
    registerDockPanel("probe", { label: "Probe", component: ProbePanel });
    registerDockPanel("other", { label: "Other", component: OtherPanel });
    activateDockTool("probe");

    await render(<template><DevToolsDockHost /></template>);

    await click(document.querySelectorAll("[role='tab']")[1]);

    assert.strictEqual(dockState().activeTool, "other");
    assert.dom("[data-test-dock-panel='other']").exists();
  });

  test("closing from the dock clears the open flag", async function (assert) {
    registerDockPanel("probe", { label: "Probe", component: ProbePanel });
    activateDockTool("probe");

    await render(<template><DevToolsDockHost /></template>);

    await click(".d-panel-dock__close");

    assert.false(dockState().open);
    assert.dom(".d-panel-dock").doesNotExist();
  });

  test("re-registering a tool replaces its panel instead of adding one", async function (assert) {
    registerDockPanel("probe", { label: "Probe", component: ProbePanel });
    registerDockPanel("probe", { label: "Probe", component: OtherPanel });
    registerDockPanel("other", { label: "Other", component: ProbePanel });
    activateDockTool("probe");

    await render(<template><DevToolsDockHost /></template>);

    assert.strictEqual(dockPanels().length, 2, "one entry per tool");
    assert.dom("[role='tab']").exists({ count: 2 });
    assert
      .dom("[data-test-dock-panel='other']")
      .exists("the later registration wins");
  });
});
