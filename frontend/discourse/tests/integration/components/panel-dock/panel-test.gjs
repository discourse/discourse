import { on } from "@ember/modifier";
import { click, render, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import KeyValueStore from "discourse/lib/key-value-store";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import PanelDockChassis from "discourse/ui-kit/panel-dock/-internals/panel";

const RESIZER = ".d-panel-dock__resizer";
const PICKER = ".d-panel-dock__dock-picker";
const MIN_WIDTH = 240;
const MAX_WIDTH = 720;
const DEFAULT_WIDTH = 320;
const MIN_HEIGHT = 160;
const DEFAULT_HEIGHT = 320;
const KEYBOARD_STEP = 16;

function store() {
  return new KeyValueStore("d_panel_dock_");
}

function renderedSize(property) {
  return parseInt(
    document.querySelector(".d-panel-dock").style.getPropertyValue(property),
    10
  );
}

function renderedWidth() {
  return renderedSize("--d-panel-dock-width");
}

function renderedHeight() {
  return renderedSize("--d-panel-dock-height");
}

function maxHeight() {
  return Math.min(600, Math.round(window.innerHeight * 0.8));
}

module("Integration | Component | PanelDockChassis", function (hooks) {
  setupRenderingTest(hooks);

  test("renders only when open", async function (assert) {
    await render(<template><PanelDockChassis @isOpen={{false}} /></template>);
    assert.dom(".d-panel-dock").doesNotExist();

    await render(<template><PanelDockChassis @isOpen={{true}} /></template>);
    assert.dom(".d-panel-dock").exists();
  });

  test("yields a header and a body", async function (assert) {
    await render(
      <template>
        <PanelDockChassis @isOpen={{true}}>
          <:header>Panel title</:header>
          <:body>Panel content</:body>
        </PanelDockChassis>
      </template>
    );

    assert.dom(".d-panel-dock__header").hasText("Panel title");
    assert.dom(".d-panel-dock__body").hasText("Panel content");
  });

  test("omits the header when none is given", async function (assert) {
    await render(
      <template>
        <PanelDockChassis @isOpen={{true}}><:body>Only a body</:body></PanelDockChassis>
      </template>
    );

    assert.dom(".d-panel-dock__header").doesNotExist();
    assert.dom(".d-panel-dock__body").hasText("Only a body");
  });

  test("the resizer describes itself as a splitter", async function (assert) {
    await render(<template><PanelDockChassis @isOpen={{true}} /></template>);

    assert.dom(RESIZER).hasAttribute("role", "separator");
    assert.dom(RESIZER).hasAttribute("aria-orientation", "vertical");
    assert.dom(RESIZER).hasAttribute("tabindex", "0");
    assert.dom(RESIZER).hasAttribute("aria-valuenow", String(DEFAULT_WIDTH));
    assert.dom(RESIZER).hasAttribute("aria-valuemin", String(MIN_WIDTH));
    assert.dom(RESIZER).hasAttribute("aria-valuemax", String(MAX_WIDTH));
    assert.dom(RESIZER).hasAttribute("aria-label");
  });

  test("arrow keys resize the panel", async function (assert) {
    await render(<template><PanelDockChassis @isOpen={{true}} /></template>);

    await triggerKeyEvent(RESIZER, "keydown", "ArrowRight");
    assert.strictEqual(
      renderedWidth(),
      DEFAULT_WIDTH + KEYBOARD_STEP,
      "grows away from the edge it is docked to"
    );

    await triggerKeyEvent(RESIZER, "keydown", "ArrowLeft");
    await triggerKeyEvent(RESIZER, "keydown", "ArrowLeft");
    assert.strictEqual(renderedWidth(), DEFAULT_WIDTH - KEYBOARD_STEP);
  });

  test("Home and End jump to the smallest and largest sizes", async function (assert) {
    await render(<template><PanelDockChassis @isOpen={{true}} /></template>);

    await triggerKeyEvent(RESIZER, "keydown", "End");
    assert.strictEqual(renderedWidth(), MAX_WIDTH);
    assert.dom(RESIZER).hasAttribute("aria-valuenow", String(MAX_WIDTH));

    await triggerKeyEvent(RESIZER, "keydown", "Home");
    assert.strictEqual(renderedWidth(), MIN_WIDTH);
  });

  test("stores its layout when a storage key is given", async function (assert) {
    await render(
      <template>
        <PanelDockChassis @isOpen={{true}} @storageKey="a-panel" />
      </template>
    );

    await triggerKeyEvent(RESIZER, "keydown", "End");
    await triggerKeyEvent(RESIZER, "keyup", "End");

    assert.deepEqual(
      store().getObject("a-panel"),
      {
        mode: "docked",
        side: "start",
        width: MAX_WIDTH,
        height: DEFAULT_HEIGHT,
      },
      "the whole layout is kept for the next time the panel is opened"
    );
  });

  test("restores a stored layout", async function (assert) {
    store().setObject({
      key: "a-panel",
      value: { side: "start", width: 500, height: DEFAULT_HEIGHT },
    });

    await render(
      <template>
        <PanelDockChassis @isOpen={{true}} @storageKey="a-panel" />
      </template>
    );

    assert.strictEqual(renderedWidth(), 500);
  });

  test("clamps a stored width that is out of range", async function (assert) {
    store().setObject({
      key: "a-panel",
      value: { side: "start", width: 5000, height: DEFAULT_HEIGHT },
    });

    await render(
      <template>
        <PanelDockChassis @isOpen={{true}} @storageKey="a-panel" />
      </template>
    );

    assert.strictEqual(renderedWidth(), MAX_WIDTH);
  });

  test("ignores a stored value that is not a layout object", async function (assert) {
    store().setObject({ key: "a-panel", value: 500 });

    await render(
      <template>
        <PanelDockChassis @isOpen={{true}} @storageKey="a-panel" />
      </template>
    );

    assert.strictEqual(
      renderedWidth(),
      DEFAULT_WIDTH,
      "an unrecognized shape falls back to the defaults"
    );
  });

  test("does not store a layout without a storage key", async function (assert) {
    await render(<template><PanelDockChassis @isOpen={{true}} /></template>);

    await triggerKeyEvent(RESIZER, "keydown", "End");

    assert.strictEqual(renderedWidth(), MAX_WIDTH, "still resizes");
    assert.strictEqual(
      store().getObject("a-panel"),
      undefined,
      "but nothing is written"
    );
  });

  test("has no dock picker unless it is dockable", async function (assert) {
    await render(
      <template>
        <PanelDockChassis @isOpen={{true}}><:header
          >Title</:header></PanelDockChassis>
      </template>
    );

    assert.dom(PICKER).doesNotExist();
    assert
      .dom(".d-panel-dock")
      .hasClass("--dock-start", "the panel still docks to the default side");
  });

  test("a dockable panel offers all three sides and marks the active one", async function (assert) {
    await render(
      <template>
        <PanelDockChassis @isOpen={{true}} @dockable={{true}}>
          <:header>Title</:header>
        </PanelDockChassis>
      </template>
    );

    assert.dom(PICKER).hasAttribute("role", "group");
    assert.dom(`${PICKER} [aria-label]`).exists({ count: 3 });
    assert.dom(`${PICKER} .--start`).hasAttribute("aria-pressed", "true");
    assert.dom(`${PICKER} .--bottom`).hasAttribute("aria-pressed", "false");
    assert.dom(`${PICKER} .--end`).hasAttribute("aria-pressed", "false");
  });

  test("docking to the bottom switches the panel and its resizer to the height axis", async function (assert) {
    await render(
      <template>
        <PanelDockChassis @isOpen={{true}} @dockable={{true}}>
          <:header>Title</:header>
        </PanelDockChassis>
      </template>
    );

    await click(`${PICKER} .--bottom`);

    assert.dom(".d-panel-dock").hasClass("--dock-bottom");
    assert.dom(`${PICKER} .--bottom`).hasAttribute("aria-pressed", "true");
    assert.dom(RESIZER).hasAttribute("aria-orientation", "horizontal");
    assert.dom(RESIZER).hasAttribute("aria-valuenow", String(DEFAULT_HEIGHT));
    assert.dom(RESIZER).hasAttribute("aria-valuemin", String(MIN_HEIGHT));
    assert.dom(RESIZER).hasAttribute("aria-valuemax", String(maxHeight()));
    assert.strictEqual(renderedHeight(), DEFAULT_HEIGHT);
  });

  test("a bottom-docked panel grows upward from the keyboard", async function (assert) {
    await render(
      <template>
        <PanelDockChassis @isOpen={{true}} @dockable={{true}}>
          <:header>Title</:header>
        </PanelDockChassis>
      </template>
    );

    await click(`${PICKER} .--bottom`);

    await triggerKeyEvent(RESIZER, "keydown", "ArrowUp");
    assert.strictEqual(
      renderedHeight(),
      DEFAULT_HEIGHT + KEYBOARD_STEP,
      "the top edge grows away from the bottom it is docked to"
    );

    await triggerKeyEvent(RESIZER, "keydown", "ArrowDown");
    await triggerKeyEvent(RESIZER, "keydown", "ArrowDown");
    assert.strictEqual(renderedHeight(), DEFAULT_HEIGHT - KEYBOARD_STEP);

    await triggerKeyEvent(RESIZER, "keydown", "End");
    assert.strictEqual(renderedHeight(), maxHeight());
  });

  test("an end-docked panel grows toward the start from the keyboard", async function (assert) {
    await render(
      <template>
        <PanelDockChassis @isOpen={{true}} @dockable={{true}}>
          <:header>Title</:header>
        </PanelDockChassis>
      </template>
    );

    await click(`${PICKER} .--end`);

    assert.dom(".d-panel-dock").hasClass("--dock-end");
    assert.dom(RESIZER).hasAttribute("aria-orientation", "vertical");

    await triggerKeyEvent(RESIZER, "keydown", "ArrowLeft");
    assert.strictEqual(
      renderedWidth(),
      DEFAULT_WIDTH + KEYBOARD_STEP,
      "growing away from the end edge means moving toward the start"
    );
  });

  test("starts from the default width argument until a stored width wins", async function (assert) {
    await render(
      <template>
        <PanelDockChassis @isOpen={{true}} @defaultWidth={{420}} />
      </template>
    );

    assert.strictEqual(renderedWidth(), 420);

    store().setObject({
      key: "a-panel",
      value: { side: "start", width: 500, height: DEFAULT_HEIGHT },
    });

    await render(
      <template>
        <PanelDockChassis
          @isOpen={{true}}
          @storageKey="a-panel"
          @defaultWidth={{420}}
        />
      </template>
    );

    assert.strictEqual(renderedWidth(), 500, "a stored width wins");
  });

  test("a chosen side starts from the default side argument", async function (assert) {
    await render(
      <template>
        <PanelDockChassis
          @isOpen={{true}}
          @dockable={{true}}
          @defaultSide="end"
        >
          <:header>Title</:header>
        </PanelDockChassis>
      </template>
    );

    assert.dom(".d-panel-dock").hasClass("--dock-end");
    assert.dom(`${PICKER} .--end`).hasAttribute("aria-pressed", "true");
  });

  test("the chosen side and size persist together", async function (assert) {
    await render(
      <template>
        <PanelDockChassis
          @isOpen={{true}}
          @dockable={{true}}
          @storageKey="a-panel"
        >
          <:header>Title</:header>
        </PanelDockChassis>
      </template>
    );

    await click(`${PICKER} .--bottom`);
    await triggerKeyEvent(RESIZER, "keydown", "End");
    await triggerKeyEvent(RESIZER, "keyup", "End");

    assert.deepEqual(store().getObject("a-panel"), {
      mode: "docked",
      side: "bottom",
      width: DEFAULT_WIDTH,
      height: maxHeight(),
    });

    await render(
      <template>
        <PanelDockChassis
          @isOpen={{true}}
          @dockable={{true}}
          @storageKey="a-panel"
        >
          <:header>Title</:header>
        </PanelDockChassis>
      </template>
    );

    assert.dom(".d-panel-dock").hasClass("--dock-bottom");
    assert.strictEqual(renderedHeight(), maxHeight());
  });

  test("notifies when a side is chosen", async function (assert) {
    const chosen = [];
    const record = (side) => chosen.push(side);

    await render(
      <template>
        <PanelDockChassis
          @isOpen={{true}}
          @dockable={{true}}
          @onDock={{record}}
        >
          <:header>Title</:header>
        </PanelDockChassis>
      </template>
    );

    await click(`${PICKER} .--bottom`);
    await click(`${PICKER} .--start`);

    assert.deepEqual(chosen, ["bottom", "start"]);
  });

  test("yields actions into the header after the dock picker", async function (assert) {
    await render(
      <template>
        <PanelDockChassis @isOpen={{true}} @dockable={{true}}>
          <:header>Title</:header>
          <:actions><button
              type="button"
              class="an-action"
            >Go</button></:actions>
        </PanelDockChassis>
      </template>
    );

    const header = document.querySelector(".d-panel-dock__header");
    const picker = header.querySelector(PICKER);
    const action = header.querySelector(".an-action");

    assert.true(!!picker, "the picker is in the header");
    assert.true(!!action, "the actions block is in the header");

    const ordered = [...header.querySelectorAll(`${PICKER}, .an-action`)];
    assert.true(
      ordered.indexOf(picker) < ordered.indexOf(action),
      "the caller's actions come after the picker, so a close button stays last"
    );
  });

  test("stays open when the page behind it is clicked", async function (assert) {
    let clicked = false;
    const record = () => (clicked = true);

    await render(
      <template>
        <button type="button" class="behind-panel" {{on "click" record}}>
          Behind
        </button>
        <PanelDockChassis @isOpen={{true}}><:body
          >Content</:body></PanelDockChassis>
      </template>
    );

    await click(".behind-panel");

    assert.true(clicked, "the click reaches the page");
    assert.dom(".d-panel-dock").exists("the panel is not dismissed");
  });
});
