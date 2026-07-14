import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import BlockOutlet, {
  _resetOutletLayoutsForTesting,
} from "discourse/blocks/block-outlet";
import Heading from "discourse/blocks/builtin/heading";
import Layout from "discourse/blocks/builtin/layout";
import Tabs from "discourse/blocks/builtin/tabs";
import {
  DEBUG_CALLBACK,
  debugHooks,
} from "discourse/lib/blocks/-internals/debug-hooks";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

// Each tab panel is a `layout` block (the `tabs` `childBlocks` contract), so a
// panel wraps its content in a layout and carries the tab label on that layout.
function panel(text, label) {
  const entry = {
    block: Layout,
    args: {},
    children: [{ block: Heading, args: { text } }],
  };
  if (label !== undefined) {
    entry.containerArgs = { tab: { label } };
  }
  return entry;
}

module("Integration | Blocks | tabs", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    _resetOutletLayoutsForTesting();
    debugHooks.setCallback(DEBUG_CALLBACK.EDIT_PRESENTATION, null);
  });

  test("renders a strip from child labels and only the active panel", async function (assert) {
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: Tabs,
          args: {},
          children: [
            panel("Inside first", "First"),
            panel("Inside second", "Second"),
          ],
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    const tabs = [...document.querySelectorAll(".d-block-tabs__tab")];
    assert.strictEqual(tabs.length, 2, "renders a tab per child");
    assert.dom(tabs[0]).hasText("First", "reads the label from containerArgs");
    assert.dom(tabs[1]).hasText("Second");
    assert
      .dom(tabs[0])
      .hasAttribute("aria-selected", "true", "the first tab starts active");

    assert
      .dom(".d-block-tabs__panel .d-block-heading")
      .exists({ count: 1 }, "renders only the active panel live");
    assert
      .dom(".d-block-tabs__panel .d-block-heading")
      .hasText("Inside first", "the active panel is the first child");
  });

  test("falls back to a numbered label when a child has no label", async function (assert) {
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: Tabs,
          args: {},
          children: [panel("Inside first"), panel("Inside second")],
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    const tabs = [...document.querySelectorAll(".d-block-tabs__tab")];
    assert.dom(tabs[0]).hasText("Tab 1", "unlabelled tabs fall back to Tab N");
    assert.dom(tabs[1]).hasText("Tab 2");
  });

  test("clicking a tab switches the active panel", async function (assert) {
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: Tabs,
          args: {},
          children: [
            panel("Inside first", "First"),
            panel("Inside second", "Second"),
          ],
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    await click(document.querySelectorAll(".d-block-tabs__tab")[1]);

    assert
      .dom(".d-block-tabs__panel .d-block-heading")
      .hasText("Inside second", "the clicked panel becomes active");
    assert
      .dom(document.querySelectorAll(".d-block-tabs__tab")[1])
      .hasAttribute("aria-selected", "true", "the clicked tab is selected");
  });

  test("renders no add-tab affordance on the live page", async function (assert) {
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: Tabs,
          args: {},
          children: [panel("Inside first", "First")],
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom("[data-wf-append-child]")
      .doesNotExist("the add affordance is editor-only");
  });

  test("stays functional under edit presentation — active panel only, with edit affordances", async function (assert) {
    debugHooks.setCallback(DEBUG_CALLBACK.EDIT_PRESENTATION, () => true);

    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: Tabs,
          args: {},
          children: [
            panel("Inside first", "First"),
            panel("Inside second", "Second"),
          ],
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    // Functional, not stacked: only the active (first) panel renders.
    assert
      .dom(".d-block-tabs__panel .d-block-heading")
      .exists({ count: 1 }, "only the active panel renders, not all stacked");
    assert
      .dom(".d-block-tabs__panel .d-block-heading")
      .hasText("Inside first", "the active panel is the first tab");

    // Every tab carries its panel key so a click can select that panel.
    assert
      .dom(".d-block-tabs__strip [data-wf-tab-panel-key]")
      .exists({ count: 2 }, "each tab carries its panel key");

    // In an editing context the tablist also doubles as a horizontal insert
    // track, and each tab proxies its panel so a drop between tabs lands a new
    // tab at that position.
    assert
      .dom(
        ".d-block-tabs__tablist[data-wf-drop-container][data-wf-drop-axis='x']"
      )
      .exists("the tablist is a horizontal drop container");
    assert
      .dom(".d-block-tabs__strip [data-wf-drop-child-key]")
      .exists({ count: 2 }, "each tab proxies its panel key for inserts");

    // Only the ACTIVE tab is an inline-edit target, so the edit affordance
    // doesn't show on tabs the author isn't on.
    const labelHosts = [
      ...document.querySelectorAll(
        ".d-block-tabs__strip [data-wf-container-arg-key]"
      ),
    ];
    assert.strictEqual(
      labelHosts.length,
      1,
      "only the active tab is an edit target"
    );
    assert
      .dom(labelHosts[0])
      .hasAttribute("data-wf-container-arg-namespace", "tab")
      .hasAttribute("data-wf-container-arg-field", "label");

    // The trailing append-tab affordance is offered for adding another tab.
    assert
      .dom(".d-block-tabs__strip [data-wf-append-child]")
      .exists("the add-tab affordance is rendered in the editing strip");
  });

  test("clicking a tab switches the rendered panel under edit presentation", async function (assert) {
    debugHooks.setCallback(DEBUG_CALLBACK.EDIT_PRESENTATION, () => true);

    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: Tabs,
          args: {},
          children: [
            panel("Inside first", "First"),
            panel("Inside second", "Second"),
          ],
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom(".d-block-tabs__panel .d-block-heading")
      .hasText("Inside first", "starts on the first tab");

    await click(document.querySelectorAll(".d-block-tabs__tab")[1]);

    assert
      .dom(".d-block-tabs__panel .d-block-heading")
      .hasText("Inside second", "switching tabs reveals the other panel");
    assert
      .dom(".d-block-tabs__panel .d-block-heading")
      .exists({ count: 1 }, "still only one panel renders after switching");
  });
});
