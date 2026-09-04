import { tracked } from "@glimmer/tracking";
import {
  clearRender,
  click,
  render,
  settled,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import KeyValueStore from "discourse/lib/key-value-store";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { IframeWindowHost } from "discourse/tests/helpers/panel-dock-window-host";
import DPanelDock from "discourse/ui-kit/panel-dock";
import { WINDOW_HOST_REGISTRATION } from "discourse/ui-kit/panel-dock/-internals/window-host";

const PanelA = <template>
  <div data-test-panel="a">alpha panel content</div>
</template>;

const PanelB = <template>
  <div data-test-panel="b">beta panel content</div>
</template>;

const PanelC = <template>
  <div data-test-panel="c">gamma panel content</div>
</template>;

function threeTabs() {
  return [
    { id: "alpha", label: "Alpha", component: PanelA },
    { id: "beta", label: "Beta", component: PanelB },
    { id: "gamma", label: "Gamma", component: PanelC },
  ];
}

/**
 * Oracle for the `DPanelDock` public core (unit U3). The persisted-layout
 * cases seed the store namespace the dock derives from its `@context`, so
 * they pin both the schema tolerance and the context-keyed storage in one
 * observation.
 */
module("Integration | Component | DPanelDock", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    this.windowHost?.teardown();
  });

  function registerWindowHost(context) {
    context.windowHost = new IframeWindowHost();
    context.owner.register(WINDOW_HOST_REGISTRATION, context.windowHost, {
      instantiate: false,
    });
    return context.windowHost;
  }

  test("renders the active tab's content in a labelled tabpanel", async function (assert) {
    const tabs = threeTabs();

    await render(
      <template>
        <DPanelDock @context="test-tools" @isOpen={{true}} @tabs={{tabs}} />
      </template>
    );

    assert.dom("[role='tablist']").exists("the tab strip is a tablist");
    assert
      .dom("[role='tablist']")
      .hasAttribute("aria-label", /.+/, "the tablist carries a label");
    assert.dom("[role='tab']").exists({ count: 3 });

    const firstTab = document.querySelector("[role='tab']");
    assert
      .dom(firstTab)
      .hasAria("selected", "true", "the first tab is active by default");

    const panel = document.querySelector("[role='tabpanel']");
    assert.dom(panel).exists("the active tab renders a tabpanel");
    assert
      .dom("[data-test-panel='a']", panel)
      .exists("the tabpanel hosts the active tab's component");
    assert
      .dom("[data-test-panel='b']")
      .doesNotExist("inactive tab components do not render");

    assert.strictEqual(
      panel.getAttribute("aria-labelledby"),
      firstTab.id,
      "the tabpanel is labelled by its tab"
    );
    assert.strictEqual(
      firstTab.getAttribute("aria-controls"),
      panel.id,
      "the tab points at the panel it controls"
    );
  });

  test("renders no tab strip for a single tab", async function (assert) {
    const tabs = [{ id: "alpha", label: "Alpha", component: PanelA }];

    await render(
      <template>
        <DPanelDock @context="test-tools" @isOpen={{true}} @tabs={{tabs}} />
      </template>
    );

    assert.dom("[role='tablist']").doesNotExist("a single tab needs no strip");
    assert
      .dom("[data-test-panel='a']")
      .exists("the lone tab's content still renders");
  });

  test("activates a tab on click and reports it", async function (assert) {
    const tabs = threeTabs();
    const activated = [];
    const onActivateTab = (id) => activated.push(id);

    await render(
      <template>
        <DPanelDock
          @context="test-tools"
          @isOpen={{true}}
          @tabs={{tabs}}
          @onActivateTab={{onActivateTab}}
        />
      </template>
    );

    const second = document.querySelectorAll("[role='tab']")[1];
    await click(second);

    assert.deepEqual(activated, ["beta"], "the callback names the tab");
    assert
      .dom("[data-test-panel='b']")
      .exists("the clicked tab's content renders");
    assert.dom("[data-test-panel='a']").doesNotExist();
    assert.dom(second).hasAria("selected", "true");
  });

  test("honors a controlled active tab", async function (assert) {
    const tabs = threeTabs();
    const activated = [];
    const state = new (class {
      @tracked activeTab = "beta";
    })();
    const onActivateTab = (id) => activated.push(id);

    await render(
      <template>
        <DPanelDock
          @context="test-tools"
          @isOpen={{true}}
          @tabs={{tabs}}
          @activeTab={{state.activeTab}}
          @onActivateTab={{onActivateTab}}
        />
      </template>
    );

    assert.dom("[data-test-panel='b']").exists("the controlled tab renders");
    assert
      .dom("[role='tab'][aria-selected='true']")
      .hasAttribute(
        "tabindex",
        "0",
        "the tab stop seeds on the selected tab, not the first"
      );

    await click(document.querySelectorAll("[role='tab']")[0]);
    assert.deepEqual(activated, ["alpha"], "a click still reports");
    assert
      .dom("[data-test-panel='b']")
      .exists("content does not change until the owner updates the arg");

    state.activeTab = "alpha";
    await settled();
    assert
      .dom("[data-test-panel='a']")
      .exists("updating the arg switches the content");
  });

  test("moves tab focus with arrows without activating", async function (assert) {
    const tabs = threeTabs();

    await render(
      <template>
        <DPanelDock @context="test-tools" @isOpen={{true}} @tabs={{tabs}} />
      </template>
    );

    const [first, second, third] = [
      ...document.querySelectorAll("[role='tab']"),
    ];
    first.focus();

    await triggerKeyEvent(first, "keydown", "ArrowRight");
    assert.strictEqual(document.activeElement, second, "arrow moves focus");
    assert
      .dom(second)
      .hasAttribute("tabindex", "0", "focused tab joins the tab order");
    assert
      .dom(first)
      .hasAttribute("tabindex", "-1", "the rest leave the tab order");
    assert
      .dom(first)
      .hasAria("selected", "true", "focus alone does not activate");

    await triggerKeyEvent(second, "keydown", "End");
    assert.strictEqual(document.activeElement, third, "End reaches the last");

    await triggerKeyEvent(third, "keydown", "Home");
    assert.strictEqual(document.activeElement, first, "Home returns first");
  });

  test("activates the focused tab with Enter and with Space", async function (assert) {
    const tabs = threeTabs();

    await render(
      <template>
        <DPanelDock @context="test-tools" @isOpen={{true}} @tabs={{tabs}} />
      </template>
    );

    const [first, second, third] = [
      ...document.querySelectorAll("[role='tab']"),
    ];
    first.focus();

    await triggerKeyEvent(first, "keydown", "ArrowRight");
    await triggerKeyEvent(second, "keydown", "Enter");
    assert.dom("[data-test-panel='b']").exists("Enter activates");

    await triggerKeyEvent(second, "keydown", "ArrowRight");
    await triggerKeyEvent(third, "keydown", " ");
    assert.dom("[data-test-panel='c']").exists("Space activates");
  });

  test("closes from its close button", async function (assert) {
    const tabs = threeTabs();
    let closed = 0;
    const onClose = () => (closed += 1);

    await render(
      <template>
        <DPanelDock
          @context="test-tools"
          @isOpen={{true}}
          @tabs={{tabs}}
          @onClose={{onClose}}
        />
      </template>
    );

    await click(".d-panel-dock__close");
    assert.strictEqual(closed, 1, "the close callback fired once");
  });

  test("carries its context on the root element", async function (assert) {
    const tabs = threeTabs();

    await render(
      <template>
        <DPanelDock @context="test-tools" @isOpen={{true}} @tabs={{tabs}} />
      </template>
    );

    assert
      .dom(".d-panel-dock.--context-test-tools")
      .exists("the root names the dock and its context");
  });

  test("restores a persisted docked layout by context", async function (assert) {
    new KeyValueStore("d_panel_dock_").setObject({
      key: "test-tools",
      value: { mode: "docked", side: "end", width: 400, height: 300 },
    });
    const tabs = threeTabs();

    await render(
      <template>
        <DPanelDock @context="test-tools" @isOpen={{true}} @tabs={{tabs}} />
      </template>
    );

    assert.dom("[class*='--dock-end']").exists("the stored side is restored");
  });

  test("falls back to docked for an unknown persisted mode", async function (assert) {
    new KeyValueStore("d_panel_dock_").setObject({
      key: "test-tools",
      value: { mode: "holographic", side: "end", width: 400, height: 300 },
    });
    const tabs = threeTabs();

    await render(
      <template>
        <DPanelDock @context="test-tools" @isOpen={{true}} @tabs={{tabs}} />
      </template>
    );

    assert
      .dom("[data-test-panel='a']")
      .exists("an unknown mode never breaks rendering");
    assert
      .dom("[class*='--dock-end']")
      .exists("the recognizable parts of the layout still apply");
  });

  test("window mode falls back and is rewritten when its window is gone", async function (assert) {
    const store = new KeyValueStore("d_panel_dock_");
    const geometry = { width: 800, height: 600, left: 40, top: 40 };
    store.setObject({
      key: "test-tools",
      value: {
        mode: "window",
        side: "bottom",
        width: 400,
        height: 300,
        window: geometry,
      },
    });
    const host = registerWindowHost(this);
    const tabs = threeTabs();

    await render(
      <template>
        <DPanelDock
          @context="test-tools"
          @isOpen={{true}}
          @tabs={{tabs}}
          @windowable={{true}}
        />
      </template>
    );

    assert.strictEqual(
      host.adoptCount,
      1,
      "the public component tries to adopt"
    );
    assert
      .dom("[data-test-panel='a']")
      .exists("the content falls back into the page");
    assert
      .dom("[class*='--dock-bottom']")
      .exists("the docked side still applies");
    assert.deepEqual(store.getObject("test-tools"), {
      mode: "docked",
      side: "bottom",
      width: 400,
      height: 300,
      window: geometry,
    });
  });

  test("window mode is never adopted by a panel that is not windowable", async function (assert) {
    const store = new KeyValueStore("d_panel_dock_");
    const original = {
      mode: "window",
      side: "end",
      width: 410,
      height: 310,
      window: { width: 780, height: 560, left: 50, top: 60 },
    };
    store.setObject({ key: "test-tools", value: original });
    const host = registerWindowHost(this);
    host.seedPreparedWindow("test-tools", "test-tools");
    const tabs = threeTabs();

    await render(
      <template>
        <DPanelDock
          @context="test-tools"
          @isOpen={{true}}
          @tabs={{tabs}}
          @windowable={{false}}
        />
      </template>
    );

    assert.strictEqual(host.adoptCount, 0, "the host is never asked");
    assert.dom("[class*='--dock-end']").exists("the panel renders docked");
    assert.deepEqual(
      store.getObject("test-tools"),
      original,
      "storage for a window it cannot own is untouched"
    );

    await clearRender();
    await render(
      <template>
        <DPanelDock
          @context="test-tools"
          @isOpen={{true}}
          @tabs={{tabs}}
          @windowable={{true}}
        />
      </template>
    );

    assert.strictEqual(host.adoptCount, 1, "an eligible panel does ask");
    assert
      .dom("[data-test-panel='a']", host.windowFor("test-tools").document)
      .exists("the prepared window receives the public panel");
  });

  test("keeps the same panel element when the tab count crosses one", async function (assert) {
    const state = new (class {
      @tracked
      tabs = [
        { id: "alpha", label: "Alpha", component: PanelA },
        { id: "beta", label: "Beta", component: PanelB },
      ];
    })();

    await render(
      <template>
        <DPanelDock
          @context="test-tools"
          @isOpen={{true}}
          @tabs={{state.tabs}}
        />
      </template>
    );

    const panel = document.querySelector(".d-panel-dock");
    assert.dom(panel).exists("the panel is rendered with two tabs");

    state.tabs = [{ id: "alpha", label: "Alpha", component: PanelA }];
    await settled();

    assert.dom("[role='tablist']").doesNotExist("a lone tab loses the strip");
    assert.strictEqual(
      document.querySelector(".d-panel-dock"),
      panel,
      "dropping to one tab reshapes the panel rather than rebuilding it"
    );

    state.tabs = [
      { id: "alpha", label: "Alpha", component: PanelA },
      { id: "beta", label: "Beta", component: PanelB },
    ];
    await settled();

    assert.dom("[role='tablist']").exists("a second tab brings the strip back");
    assert.strictEqual(
      document.querySelector(".d-panel-dock"),
      panel,
      "and growing back is the same panel too"
    );
  });

  test("keeps the header row for a lone tab with no close button", async function (assert) {
    const tabs = [{ id: "alpha", label: "Alpha", component: PanelA }];

    await render(
      <template>
        <DPanelDock @context="test-tools" @isOpen={{true}} @tabs={{tabs}} />
      </template>
    );

    assert
      .dom(".d-panel-dock__header")
      .exists("the header row is not conditional on having controls in it");
    assert
      .dom(".d-panel-dock__actions")
      .exists("and neither is the slot those controls would go in");
    assert
      .dom("[data-test-panel='a']")
      .exists("the lone tab's content is the body");
  });

  test("reflects a tabs change without losing the open panel", async function (assert) {
    const state = new (class {
      @tracked
      tabs = [
        { id: "alpha", label: "Alpha", component: PanelA },
        { id: "beta", label: "Beta", component: PanelB },
      ];
    })();

    await render(
      <template>
        <DPanelDock
          @context="test-tools"
          @isOpen={{true}}
          @tabs={{state.tabs}}
        />
      </template>
    );

    assert.dom("[role='tab']").exists({ count: 2 });

    state.tabs = [
      ...state.tabs,
      { id: "gamma", label: "Gamma", component: PanelC },
    ];
    await settled();

    assert.dom("[role='tab']").exists({ count: 3 }, "the strip follows @tabs");
    assert
      .dom("[data-test-panel='a']")
      .exists("the active tab's content survives the change");
  });
});
