import { tracked } from "@glimmer/tracking";
import { run, schedule } from "@ember/runloop";
import { clearRender, click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import KeyValueStore from "discourse/lib/key-value-store";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { IframeWindowHost } from "discourse/tests/helpers/panel-dock-window-host";
import PanelDockChassis from "discourse/ui-kit/panel-dock/-internals/panel";
import { WINDOW_HOST_REGISTRATION } from "discourse/ui-kit/panel-dock/-internals/window-host";

const STORE_NAMESPACE = "d_panel_dock_";
const WINDOW_BUTTON = ".d-panel-dock__dock-button.--window";

function store() {
  return new KeyValueStore(STORE_NAMESPACE);
}

function popupPanel(host, key) {
  return host.windowFor(key).document.querySelector(".d-panel-dock");
}

function popupButton(host, key, selector) {
  return host.windowFor(key).document.querySelector(selector);
}

async function flushWindowResize(host, key) {
  await new Promise((resolve) => requestAnimationFrame(resolve));
  host.flushPopupAnimationFrame(key);
  await settled();
}

function addedDockLayer(records) {
  return records.some((record) =>
    [...record.addedNodes].some(
      (node) =>
        node.nodeType === Node.ELEMENT_NODE &&
        (node.matches(".d-panel-dock-layer") ||
          node.querySelector(".d-panel-dock-layer"))
    )
  );
}

module("Integration | Component | panel dock window mode", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.host = new IframeWindowHost();
    this.owner.register(WINDOW_HOST_REGISTRATION, this.host, {
      instantiate: false,
    });
    this.siteSettings.title = "Window mode oracle";
    store().abandonLocal();
  });

  hooks.afterEach(function () {
    this.host.teardown();
    store().abandonLocal();
    sinon.restore();
  });

  test("window mode eligibility only adds the fourth picker choice", async function (assert) {
    const state = new (class {
      @tracked windowable = false;
    })();

    await render(
      <template>
        <PanelDockChassis
          @dockable={{true}}
          @isOpen={{true}}
          @storageKey="picker-eligibility"
          @windowable={{state.windowable}}
        >
          <:header>Oracle title</:header>
          <:body>Oracle body</:body>
        </PanelDockChassis>
      </template>
    );

    assert.dom(".d-panel-dock__dock-button").exists({ count: 3 });
    assert.dom(WINDOW_BUTTON).doesNotExist("window mode is not offered yet");
    assert.dom(".d-panel-dock-layer").exists("the panel remains docked");
    assert.dom(".d-panel-dock__resizer").exists("docked resizing is untouched");

    state.windowable = true;
    await settled();

    assert.dom(".d-panel-dock__dock-button").exists({ count: 4 });
    assert
      .dom(WINDOW_BUTTON)
      .hasAttribute("aria-pressed", "false", "eligibility is not window mode");
    assert
      .dom(".d-panel-dock-layer")
      .exists("eligibility does not move the panel");
    assert.strictEqual(
      this.host.openCount,
      0,
      "no window is opened by rendering"
    );
  });

  test("window mode renders only the shared interior in the window document", async function (assert) {
    const modes = [];
    const onModeChange = (mode) => modes.push(mode);

    await render(
      <template>
        <PanelDockChassis
          class="caller-class"
          data-oracle-attribute="forwarded"
          @dockable={{true}}
          @isOpen={{true}}
          @onModeChange={{onModeChange}}
          @storageKey="window-rendering"
          @windowable={{true}}
        >
          <:header>Oracle title</:header>
          <:body><span data-window-body>Oracle body</span></:body>
        </PanelDockChassis>
      </template>
    );

    await click(WINDOW_BUTTON);

    const panel = popupPanel(this.host, "window-rendering");
    assert
      .dom(".d-panel-dock", this.host.windowFor("window-rendering").document)
      .exists();
    assert.dom(panel).hasClass("--window", "mode supplies the window modifier");
    assert
      .dom(panel)
      .hasClass("caller-class", "the caller's class is forwarded");
    assert.dom(panel).hasAttribute("role", "region");
    assert.dom(panel).hasAttribute("aria-label", "Panel - Window mode oracle");
    assert.dom(panel).hasAttribute("tabindex", "-1");
    assert.dom(panel).hasAttribute("data-oracle-attribute", "forwarded");
    assert
      .dom(panel.querySelector("[data-window-body]"))
      .hasText("Oracle body");
    assert.dom(panel.closest(".d-panel-dock-layer")).doesNotExist();
    assert
      .dom(panel)
      .doesNotHaveAttribute("style", "docked sizing is not forwarded");
    assert.dom(panel.querySelector(".d-panel-dock__resizer")).doesNotExist();
    assert
      .dom(".d-panel-dock-layer")
      .doesNotExist("the opener has no docked copy");
    assert.deepEqual(modes, ["window"], "the rendered mode is reported once");
    assert.strictEqual(store().getObject("window-rendering").mode, "window");
  });

  test("window mode picker presses only the window choice", async function (assert) {
    await render(
      <template>
        <PanelDockChassis
          @dockable={{true}}
          @isOpen={{true}}
          @storageKey="picker-state"
          @windowable={{true}}
        >
          <:header>Oracle title</:header>
        </PanelDockChassis>
      </template>
    );

    await click(WINDOW_BUTTON);

    const doc = this.host.windowFor("picker-state").document;
    assert
      .dom(popupButton(this.host, "picker-state", WINDOW_BUTTON))
      .hasAttribute("aria-pressed", "true");
    for (const side of ["start", "bottom", "end"]) {
      assert
        .dom(popupButton(this.host, "picker-state", `.--${side}`))
        .hasAttribute(
          "aria-pressed",
          "false",
          `${side} is not active in window mode`
        );
    }
    assert.dom(".d-panel-dock__dock-button", doc).exists({ count: 4 });
  });

  test("window mode keeps the construction storage key for leases and writes", async function (assert) {
    const state = new (class {
      @tracked storageKey = "construction-key";
    })();
    const constructionLayout = {
      mode: "docked",
      side: "end",
      width: 460,
      height: 310,
    };
    const otherLayout = {
      mode: "docked",
      side: "bottom",
      width: 510,
      height: 280,
    };
    store().setObject({ key: "construction-key", value: constructionLayout });
    store().setObject({ key: "other-key", value: otherLayout });

    await render(
      <template>
        <PanelDockChassis
          @dockable={{true}}
          @isOpen={{true}}
          @storageKey={{state.storageKey}}
          @windowable={{true}}
        />
      </template>
    );

    state.storageKey = "other-key";
    await settled();
    await click(WINDOW_BUTTON);

    assert.deepEqual(
      this.host.openKeys,
      ["construction-key"],
      "the window lease keeps using the construction key"
    );
    assert.deepEqual(
      store().getObject("other-key"),
      otherLayout,
      "the other key's stored layout is untouched"
    );
    assert.strictEqual(
      store().getObject("construction-key").mode,
      "window",
      "the rendered placement is written under the construction key"
    );
  });

  test("window mode side selection measures before closing and applies the side", async function (assert) {
    const geometry = { width: 842, height: 613, left: -91, top: 127 };
    const modes = [];
    const sides = [];
    const onDock = (side) => sides.push(side);
    const onModeChange = (mode) => modes.push(mode);

    await render(
      <template>
        <PanelDockChassis
          @dockable={{true}}
          @isOpen={{true}}
          @onDock={{onDock}}
          @onModeChange={{onModeChange}}
          @storageKey="side-return"
          @windowable={{true}}
        >
          <:header>Oracle title</:header>
        </PanelDockChassis>
      </template>
    );
    await click(WINDOW_BUTTON);
    this.host.setMeasurement("side-return", geometry);

    await click(popupButton(this.host, "side-return", ".--bottom"));

    assert.strictEqual(
      this.host.closeCount("side-return"),
      1,
      "the window closes"
    );
    assert
      .dom(".d-panel-dock.--dock-bottom")
      .exists("the chosen side is applied");
    assert.deepEqual(
      modes,
      ["window", "docked"],
      "both real modes are reported"
    );
    assert.deepEqual(sides, ["bottom"], "the side callback is preserved");
    assert.deepEqual(store().getObject("side-return"), {
      mode: "docked",
      side: "bottom",
      width: 320,
      height: 320,
      window: geometry,
    });
  });

  test("window mode reuses and focuses its existing window", async function (assert) {
    await render(
      <template>
        <PanelDockChassis
          @dockable={{true}}
          @isOpen={{true}}
          @storageKey="focus-existing"
          @windowable={{true}}
        />
      </template>
    );
    await click(WINDOW_BUTTON);

    await click(popupButton(this.host, "focus-existing", WINDOW_BUTTON));

    assert.strictEqual(this.host.openCount, 1, "a second window is not opened");
    assert.strictEqual(
      this.host.focusCount,
      1,
      "the existing window is raised"
    );
    assert
      .dom(popupPanel(this.host, "focus-existing"))
      .exists("the panel stays windowed");
  });

  test("window mode refusal leaves every docked value unchanged and warns", async function (assert) {
    const original = {
      mode: "docked",
      side: "end",
      width: 456,
      height: 321,
      window: { width: 810, height: 590, left: 17, top: 29 },
    };
    store().setObject({ key: "refused-window", value: original });
    this.host.armNextResolveRefusal();
    const warn = sinon.stub(console, "warn");
    const modes = [];
    const onModeChange = (mode) => modes.push(mode);

    await render(
      <template>
        <PanelDockChassis
          @dockable={{true}}
          @isOpen={{true}}
          @onModeChange={{onModeChange}}
          @storageKey="refused-window"
          @windowable={{true}}
        />
      </template>
    );
    await click(WINDOW_BUTTON);

    assert
      .dom(".d-panel-dock.--dock-end")
      .exists("the prior dock remains rendered");
    assert.deepEqual(store().getObject("refused-window"), original);
    assert.deepEqual(modes, [], "no transient mode is reported");
    assert.true(warn.calledOnce, "the refusal raises one warning");
  });

  test("window mode lease collision leaves storage untouched and warns", async function (assert) {
    const original = {
      mode: "docked",
      side: "bottom",
      width: 430,
      height: 275,
      window: { width: 760, height: 540, left: 31, top: 43 },
    };
    store().setObject({ key: "taken-window", value: original });
    const first = this.host.open("taken-window", {
      title: "Already held",
      note: { title: "Away", body: "Still away" },
    });
    assert.strictEqual(first.status, "acquired", "the competing lease exists");
    const warn = sinon.stub(console, "warn");

    await render(
      <template>
        <PanelDockChassis
          @dockable={{true}}
          @isOpen={{true}}
          @storageKey="taken-window"
          @windowable={{true}}
        />
      </template>
    );
    await click(WINDOW_BUTTON);

    assert
      .dom(".d-panel-dock.--dock-bottom")
      .exists("the prior dock remains rendered");
    assert.deepEqual(store().getObject("taken-window"), original);
    assert.strictEqual(this.host.openCount, 2, "the component asked once");
    assert.true(warn.calledOnce, "the collision raises one warning");
  });

  test("window mode adopts once on the first render without a docked flash", async function (assert) {
    const key = "adopt-existing";
    const state = new (class {
      @tracked body = "First body";
    })();
    const original = {
      mode: "window",
      side: "end",
      width: 470,
      height: 330,
      window: { width: 850, height: 620, left: 61, top: 73 },
    };
    store().setObject({ key, value: original });
    this.host.seedPreparedWindow(key, key);
    const fixture = document.querySelector("#ember-testing");
    const mutationRecords = [];
    const observer = new MutationObserver((records) =>
      mutationRecords.push(...records)
    );
    observer.observe(fixture, { childList: true, subtree: true });
    const modes = [];
    const onModeChange = (mode) => modes.push(mode);

    await render(
      <template>
        <PanelDockChassis
          @dockable={{true}}
          @isOpen={{true}}
          @onModeChange={{onModeChange}}
          @storageKey={{key}}
          @windowable={{true}}
        >
          <:body>{{state.body}}</:body>
        </PanelDockChassis>
      </template>
    );
    mutationRecords.push(...observer.takeRecords());
    observer.disconnect();

    assert.false(
      addedDockLayer(mutationRecords),
      "no docked panel was inserted first"
    );
    assert.dom(popupPanel(this.host, key)).includesText("First body");
    assert.strictEqual(
      this.host.adoptCount,
      1,
      "the stored window is adopted once"
    );
    assert.strictEqual(
      this.host.openCount,
      0,
      "adoption does not open a new window"
    );
    assert.deepEqual(
      modes,
      ["window"],
      "the adopted rendered mode is reported"
    );

    state.body = "Updated body";
    await settled();

    assert.dom(popupPanel(this.host, key)).includesText("Updated body");
    assert.strictEqual(this.host.adoptCount, 1, "a rerender does not re-adopt");
  });

  test("window mode missing adoption docks and rewrites only the mode", async function (assert) {
    const geometry = { width: 821, height: 577, left: -42, top: 85 };
    store().setObject({
      key: "missing-adoption",
      value: {
        mode: "window",
        side: "end",
        width: 440,
        height: 310,
        window: geometry,
      },
    });

    await render(
      <template>
        <PanelDockChassis
          @isOpen={{true}}
          @storageKey="missing-adoption"
          @windowable={{true}}
        />
      </template>
    );

    assert.strictEqual(
      this.host.adoptCount,
      1,
      "the stored mode is tried once"
    );
    assert
      .dom(".d-panel-dock.--dock-end")
      .exists("the panel falls back docked");
    assert.deepEqual(store().getObject("missing-adoption"), {
      mode: "docked",
      side: "end",
      width: 440,
      height: 310,
      window: geometry,
    });
  });

  test("window mode taken adoption docks without changing storage", async function (assert) {
    const key = "taken-adoption";
    const original = {
      mode: "window",
      side: "bottom",
      width: 410,
      height: 290,
      window: { width: 790, height: 560, left: 47, top: 59 },
    };
    store().setObject({ key, value: original });
    this.host.seedPreparedWindow(key, key);
    const first = this.host.adopt(key, {
      title: "Already held",
      note: { title: "Away", body: "Still away" },
    });
    assert.strictEqual(first.status, "acquired", "the competing lease exists");

    await render(
      <template>
        <PanelDockChassis
          @isOpen={{true}}
          @storageKey={{key}}
          @windowable={{true}}
        />
      </template>
    );

    assert.strictEqual(this.host.adoptCount, 2, "the component asks once");
    assert
      .dom(".d-panel-dock.--dock-bottom")
      .exists("the contender stays docked");
    assert.deepEqual(
      store().getObject(key),
      original,
      "the holder's storage is untouched"
    );
  });

  test("window mode adopts when windowable becomes true while already open", async function (assert) {
    const key = "later-windowable";
    const state = new (class {
      @tracked windowable = false;
    })();
    store().setObject({
      key,
      value: {
        mode: "window",
        side: "start",
        width: 420,
        height: 300,
      },
    });
    this.host.seedPreparedWindow(key, key);

    await render(
      <template>
        <PanelDockChassis
          @isOpen={{true}}
          @storageKey={{key}}
          @windowable={{state.windowable}}
        />
      </template>
    );

    assert.strictEqual(
      this.host.adoptCount,
      0,
      "an ineligible panel does not adopt"
    );
    assert
      .dom(".d-panel-dock.--dock-start")
      .exists("the panel initially stays docked");

    state.windowable = true;
    await settled();

    assert.strictEqual(
      this.host.adoptCount,
      1,
      "becoming windowable retries adoption exactly once"
    );
    assert
      .dom(popupPanel(this.host, key))
      .exists("the already-open panel moves into the prepared window");
  });

  test("window mode adoption watchdog returns an unacknowledged branch", async function (assert) {
    const key = "unacknowledged-adoption";
    const original = {
      mode: "window",
      side: "end",
      width: 440,
      height: 315,
      window: { width: 820, height: 590, left: 53, top: 71 },
    };
    const modes = [];
    const onModeChange = (mode) => modes.push(mode);
    store().setObject({ key, value: original });
    this.host.seedPreparedWindow(key, key);
    this.host.makeMountUnavailable(key);

    await render(
      <template>
        <PanelDockChassis
          @isOpen={{true}}
          @onModeChange={{onModeChange}}
          @storageKey={{key}}
          @windowable={{true}}
        />
      </template>
    );

    assert
      .dom(".d-panel-dock.--dock-end")
      .exists("a branch that never acknowledges falls back docked");
    assert.strictEqual(
      this.host.disposeCount(key),
      1,
      "the unacknowledged window lease is released"
    );
    assert.deepEqual(
      store().getObject(key),
      original,
      "an uncommitted adoption does not write storage"
    );
    assert.deepEqual(modes, [], "an uncommitted adoption is not reported");
  });

  test("window mode is never adopted while the panel is closed", async function (assert) {
    const state = new (class {
      @tracked isOpen = false;
    })();
    store().setObject({
      key: "closed-panel",
      value: {
        mode: "window",
        side: "start",
        width: 400,
        height: 300,
        window: { width: 800, height: 600, left: 40, top: 50 },
      },
    });
    this.host.seedPreparedWindow("closed-panel", "closed-panel");

    await render(
      <template>
        <PanelDockChassis
          @isOpen={{state.isOpen}}
          @storageKey="closed-panel"
          @windowable={{true}}
        />
      </template>
    );

    assert.strictEqual(
      this.host.adoptCount,
      0,
      "a closed panel never asks the host"
    );
    assert.dom(".d-panel-dock").doesNotExist();
    assert.strictEqual(store().getObject("closed-panel").mode, "window");

    state.isOpen = true;
    await settled();

    assert.strictEqual(
      this.host.adoptCount,
      1,
      "opening makes the panel eligible"
    );
    assert
      .dom(popupPanel(this.host, "closed-panel"))
      .exists("the prepared window is adopted once the panel opens");
  });

  test("window mode deferred freshness oracle does not adopt after destruction", async function (assert) {
    const key = "destroy-before-adoption-retry";
    const state = new (class {
      @tracked isOpen = false;
      @tracked renderPanel = true;
    })();
    store().setObject({
      key,
      value: {
        mode: "window",
        side: "start",
        width: 400,
        height: 300,
      },
    });
    this.host.seedPreparedWindow(key, key);

    await render(
      <template>
        {{#if state.renderPanel}}
          <PanelDockChassis
            @isOpen={{state.isOpen}}
            @storageKey={{key}}
            @windowable={{true}}
          />
        {{/if}}
      </template>
    );

    run(() => {
      state.isOpen = true;
      schedule("afterRender", () => (state.renderPanel = false));
    });
    await settled();

    assert.strictEqual(
      this.host.adoptCount,
      0,
      "a destroyed panel does not acquire the deferred adoption"
    );
  });

  test("window mode commits only after its branch really renders", async function (assert) {
    const original = { mode: "docked", side: "start", width: 400, height: 300 };
    store().setObject({ key: "closed-before-render", value: original });
    const modes = [];
    const onModeChange = (mode) => modes.push(mode);

    await render(
      <template>
        <PanelDockChassis
          @dockable={{true}}
          @isOpen={{true}}
          @onModeChange={{onModeChange}}
          @storageKey="closed-before-render"
          @windowable={{true}}
        />
      </template>
    );

    document.querySelector(WINDOW_BUTTON).click();
    this.host.closeAsReader("closed-before-render");
    await settled();

    assert.dom(".d-panel-dock.--dock-start").exists("the panel remains docked");
    assert.deepEqual(modes, [], "an unrendered transient mode is not reported");
    assert.deepEqual(store().getObject("closed-before-render"), original);
  });

  for (const readerAction of ["closeAsReader", "navigateReader"]) {
    test(`window mode returns when the reader invokes ${readerAction}`, async function (assert) {
      const key = `reader-${readerAction}`;
      const geometry = { width: 833, height: 611, left: 71, top: 93 };
      const modes = [];
      const onModeChange = (mode) => modes.push(mode);

      await render(
        <template>
          <PanelDockChassis
            @dockable={{true}}
            @isOpen={{true}}
            @onModeChange={{onModeChange}}
            @storageKey={{key}}
            @windowable={{true}}
          />
        </template>
      );
      await click(WINDOW_BUTTON);
      this.host.setMeasurement(key, geometry);

      this.host[readerAction](key);
      await settled();

      assert
        .dom(".d-panel-dock.--dock-start")
        .exists("the panel returns docked");
      assert.deepEqual(modes, ["window", "docked"]);
      assert.deepEqual(store().getObject(key), {
        mode: "docked",
        side: "start",
        width: 320,
        height: 320,
        window: geometry,
      });
    });
  }

  test("window mode closing the panel returns and closes its window", async function (assert) {
    const state = new (class {
      @tracked isOpen = true;
    })();
    const geometry = { width: 811, height: 571, left: 19, top: 37 };
    const modes = [];
    const onModeChange = (mode) => modes.push(mode);

    await render(
      <template>
        <PanelDockChassis
          @dockable={{true}}
          @isOpen={{state.isOpen}}
          @onModeChange={{onModeChange}}
          @storageKey="close-panel"
          @windowable={{true}}
        />
      </template>
    );
    await click(WINDOW_BUTTON);
    this.host.setMeasurement("close-panel", geometry);

    state.isOpen = false;
    await settled();

    assert.strictEqual(this.host.closeCount("close-panel"), 1);
    assert
      .dom(".d-panel-dock")
      .doesNotExist("the closed panel is not rendered");
    assert.deepEqual(modes, ["window", "docked"]);
    assert.deepEqual(store().getObject("close-panel").window, geometry);
    assert.strictEqual(store().getObject("close-panel").mode, "docked");
  });

  test("window mode deferred return ignores a branch that remounted", async function (assert) {
    const key = "reopened-before-return";
    const state = new (class {
      @tracked isOpen = true;
    })();

    await render(
      <template>
        <PanelDockChassis
          @dockable={{true}}
          @isOpen={{state.isOpen}}
          @storageKey={{key}}
          @windowable={{true}}
        />
      </template>
    );
    await click(WINDOW_BUTTON);

    run(() => {
      state.isOpen = false;
      schedule("afterRender", () => (state.isOpen = true));
    });
    await settled();

    assert.strictEqual(
      this.host.closeCount(key),
      0,
      "the legitimate reopened window is not closed"
    );
    assert
      .dom(popupPanel(this.host, key))
      .exists("the reopened panel remains in its window");
    assert.strictEqual(
      store().getObject(key).mode,
      "window",
      "the reopened panel remains stored as windowed"
    );
  });

  test("window mode deferred freshness oracle keeps a re-enabled window", async function (assert) {
    const key = "rewindowable-before-return";
    const state = new (class {
      @tracked windowable = true;
    })();

    await render(
      <template>
        <PanelDockChassis
          @dockable={{true}}
          @isOpen={{true}}
          @storageKey={{key}}
          @windowable={{state.windowable}}
        />
      </template>
    );
    await click(WINDOW_BUTTON);

    run(() => {
      state.windowable = false;
      schedule("afterRender", () => (state.windowable = true));
    });
    await settled();

    assert.strictEqual(
      this.host.closeCount(key),
      0,
      "a panel whose permission returned keeps its window open"
    );
  });

  test("window mode turning windowable off returns and closes its window", async function (assert) {
    const state = new (class {
      @tracked windowable = true;
    })();
    const modes = [];
    const onModeChange = (mode) => modes.push(mode);

    await render(
      <template>
        <PanelDockChassis
          @dockable={{true}}
          @isOpen={{true}}
          @onModeChange={{onModeChange}}
          @storageKey="disable-windowable"
          @windowable={{state.windowable}}
        />
      </template>
    );
    await click(WINDOW_BUTTON);

    state.windowable = false;
    await settled();

    assert.strictEqual(this.host.closeCount("disable-windowable"), 1);
    assert.dom(".d-panel-dock.--dock-start").exists("the panel returns docked");
    assert.dom(WINDOW_BUTTON).doesNotExist("window mode is no longer offered");
    assert.deepEqual(modes, ["window", "docked"]);
    assert.strictEqual(store().getObject("disable-windowable").mode, "docked");
  });

  test("window mode destruction releases without reporting a mode change", async function (assert) {
    const modes = [];
    const onModeChange = (mode) => modes.push(mode);

    await render(
      <template>
        <PanelDockChassis
          @dockable={{true}}
          @isOpen={{true}}
          @onModeChange={{onModeChange}}
          @storageKey="destroy-windowed"
          @windowable={{true}}
        />
      </template>
    );
    await click(WINDOW_BUTTON);

    await clearRender();

    assert.strictEqual(
      this.host.closeCount("destroy-windowed"),
      1,
      "the lease is released"
    );
    assert.deepEqual(
      modes,
      ["window"],
      "destroy does not report a consumer-facing return"
    );
  });

  test("window mode pending watchdog stops when the component is destroyed", async function (assert) {
    const key = "destroy-before-window-render";
    const state = new (class {
      @tracked renderPanel = true;
    })();
    const original = {
      mode: "docked",
      side: "start",
      width: 400,
      height: 300,
    };
    const modes = [];
    const onModeChange = (mode) => modes.push(mode);
    store().setObject({ key, value: original });

    await render(
      <template>
        {{#if state.renderPanel}}
          <PanelDockChassis
            @dockable={{true}}
            @isOpen={{true}}
            @onModeChange={{onModeChange}}
            @storageKey={{key}}
            @windowable={{true}}
          />
        {{/if}}
      </template>
    );

    run(() => {
      document.querySelector(WINDOW_BUTTON).click();
      state.renderPanel = false;
    });
    await settled();

    assert.strictEqual(
      this.host.measureCount(key),
      0,
      "the stale watchdog does not measure during destruction"
    );
    assert.strictEqual(
      this.host.disposeCount(key),
      1,
      "destruction does not schedule another disposal"
    );
    assert.deepEqual(
      store().getObject(key),
      original,
      "the stale watchdog does not write tracked placement"
    );
    assert.deepEqual(modes, [], "the pending placement is never reported");
  });

  test("window mode remembers throttled window geometry", async function (assert) {
    const geometry = { width: 903, height: 704, left: -211, top: 118 };

    await render(
      <template>
        <PanelDockChassis
          @dockable={{true}}
          @isOpen={{true}}
          @storageKey="resize-window"
          @windowable={{true}}
        />
      </template>
    );
    await click(WINDOW_BUTTON);

    this.host.resizeReader("resize-window", geometry);
    await flushWindowResize(this.host, "resize-window");

    assert.deepEqual(store().getObject("resize-window"), {
      mode: "window",
      side: "start",
      width: 320,
      height: 320,
      window: geometry,
    });
  });

  test("window mode geometry is not clamped to the opener viewport", async function (assert) {
    sinon.stub(window, "innerWidth").value(400);
    sinon.stub(window, "innerHeight").value(400);
    const geometry = { width: 910, height: 710, left: -180, top: 140 };
    store().setObject({
      key: "unclamped-window",
      value: {
        mode: "docked",
        side: "end",
        width: 700,
        height: 580,
        window: geometry,
      },
    });

    await render(
      <template>
        <PanelDockChassis
          @dockable={{true}}
          @isOpen={{true}}
          @storageKey="unclamped-window"
          @windowable={{true}}
        />
      </template>
    );

    assert
      .dom(".d-panel-dock__resizer")
      .hasAttribute(
        "aria-valuenow",
        "360",
        "the docked width uses the viewport cap"
      );

    await click(WINDOW_BUTTON);

    assert.deepEqual(
      this.host.measurementFor("unclamped-window"),
      geometry,
      "the separate window receives the unbounded remembered geometry"
    );
    assert
      .dom(popupPanel(this.host, "unclamped-window"))
      .doesNotHaveAttribute("style");
  });
});
