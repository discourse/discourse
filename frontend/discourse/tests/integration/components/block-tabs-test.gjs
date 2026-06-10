import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import BlockOutlet, {
  _resetOutletLayoutsForTesting,
} from "discourse/blocks/block-outlet";
import Heading from "discourse/blocks/builtin/heading";
import Tabs from "discourse/blocks/builtin/tabs";
import {
  DEBUG_CALLBACK,
  debugHooks,
} from "discourse/lib/blocks/-internals/debug-hooks";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

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
            {
              block: Heading,
              args: { text: "Inside first" },
              containerArgs: { tab: { label: "First" } },
            },
            {
              block: Heading,
              args: { text: "Inside second" },
              containerArgs: { tab: { label: "Second" } },
            },
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
          children: [
            { block: Heading, args: { text: "Inside first" } },
            { block: Heading, args: { text: "Inside second" } },
          ],
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
            {
              block: Heading,
              args: { text: "Inside first" },
              containerArgs: { tab: { label: "First" } },
            },
            {
              block: Heading,
              args: { text: "Inside second" },
              containerArgs: { tab: { label: "Second" } },
            },
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

  test("reveals every panel and keeps the strip when edit presentation is on", async function (assert) {
    debugHooks.setCallback(DEBUG_CALLBACK.EDIT_PRESENTATION, () => true);

    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: Tabs,
          args: {},
          children: [
            {
              block: Heading,
              args: { text: "Inside first" },
              containerArgs: { tab: { label: "First" } },
            },
            {
              block: Heading,
              args: { text: "Inside second" },
              containerArgs: { tab: { label: "Second" } },
            },
          ],
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom(".d-block-tabs--editing")
      .exists("switches to the expanded editing presentation");
    assert
      .dom(".d-block-tabs--editing .d-block-tabs__panel .d-block-heading")
      .exists({ count: 2 }, "every panel is revealed for editing");

    // The strip stays visible so labels are editable in place, each label span
    // carrying the markers external editing tooling targets.
    const labelHosts = [
      ...document.querySelectorAll(
        ".d-block-tabs__strip [data-wf-container-arg-key]"
      ),
    ];
    assert.strictEqual(labelHosts.length, 2, "every label is an edit target");
    assert
      .dom(labelHosts[0])
      .hasAttribute("data-wf-container-arg-namespace", "tab")
      .hasAttribute("data-wf-container-arg-field", "label");
  });
});
