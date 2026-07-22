import { on } from "@ember/modifier";
import { click, render, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import KeyValueStore from "discourse/lib/key-value-store";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DDockPanel from "discourse/ui-kit/d-dock-panel";

const RESIZER = ".d-dock-panel__resizer";
const MIN_WIDTH = 240;
const MAX_WIDTH = 720;
const DEFAULT_WIDTH = 320;
const KEYBOARD_STEP = 16;

function store() {
  return new KeyValueStore("d_dock_panel_");
}

function renderedWidth() {
  return parseInt(
    document
      .querySelector(".d-dock-panel")
      .style.getPropertyValue("--d-dock-panel-width"),
    10
  );
}

module("Integration | Component | d-dock-panel", function (hooks) {
  setupRenderingTest(hooks);

  test("renders only when open", async function (assert) {
    await render(<template><DDockPanel @isOpen={{false}} /></template>);
    assert.dom(".d-dock-panel").doesNotExist();

    await render(<template><DDockPanel @isOpen={{true}} /></template>);
    assert.dom(".d-dock-panel").exists();
  });

  test("yields a header and a body", async function (assert) {
    await render(
      <template>
        <DDockPanel @isOpen={{true}}>
          <:header>Panel title</:header>
          <:body>Panel content</:body>
        </DDockPanel>
      </template>
    );

    assert.dom(".d-dock-panel__header").hasText("Panel title");
    assert.dom(".d-dock-panel__body").hasText("Panel content");
  });

  test("omits the header when none is given", async function (assert) {
    await render(
      <template>
        <DDockPanel @isOpen={{true}}><:body>Only a body</:body></DDockPanel>
      </template>
    );

    assert.dom(".d-dock-panel__header").doesNotExist();
    assert.dom(".d-dock-panel__body").hasText("Only a body");
  });

  test("the resizer describes itself as a splitter", async function (assert) {
    await render(<template><DDockPanel @isOpen={{true}} /></template>);

    assert.dom(RESIZER).hasAttribute("role", "separator");
    assert.dom(RESIZER).hasAttribute("aria-orientation", "vertical");
    assert.dom(RESIZER).hasAttribute("tabindex", "0");
    assert.dom(RESIZER).hasAttribute("aria-valuenow", String(DEFAULT_WIDTH));
    assert.dom(RESIZER).hasAttribute("aria-valuemin", String(MIN_WIDTH));
    assert.dom(RESIZER).hasAttribute("aria-valuemax", String(MAX_WIDTH));
    assert.dom(RESIZER).hasAttribute("aria-label");
  });

  test("arrow keys resize the panel", async function (assert) {
    await render(<template><DDockPanel @isOpen={{true}} /></template>);

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
    await render(<template><DDockPanel @isOpen={{true}} /></template>);

    await triggerKeyEvent(RESIZER, "keydown", "End");
    assert.strictEqual(renderedWidth(), MAX_WIDTH);
    assert.dom(RESIZER).hasAttribute("aria-valuenow", String(MAX_WIDTH));

    await triggerKeyEvent(RESIZER, "keydown", "Home");
    assert.strictEqual(renderedWidth(), MIN_WIDTH);
  });

  test("stores the width when a storage key is given", async function (assert) {
    await render(
      <template><DDockPanel @isOpen={{true}} @storageKey="a-panel" /></template>
    );

    await triggerKeyEvent(RESIZER, "keydown", "End");

    assert.strictEqual(
      store().getObject("a-panel"),
      MAX_WIDTH,
      "the size is kept for the next time the panel is opened"
    );
  });

  test("restores a stored width", async function (assert) {
    store().setObject({ key: "a-panel", value: 500 });

    await render(
      <template><DDockPanel @isOpen={{true}} @storageKey="a-panel" /></template>
    );

    assert.strictEqual(renderedWidth(), 500);
  });

  test("clamps a stored width that is out of range", async function (assert) {
    store().setObject({ key: "a-panel", value: 5000 });

    await render(
      <template><DDockPanel @isOpen={{true}} @storageKey="a-panel" /></template>
    );

    assert.strictEqual(renderedWidth(), MAX_WIDTH);
  });

  test("does not store a width without a storage key", async function (assert) {
    await render(<template><DDockPanel @isOpen={{true}} /></template>);

    await triggerKeyEvent(RESIZER, "keydown", "End");

    assert.strictEqual(renderedWidth(), MAX_WIDTH, "still resizes");
    assert.strictEqual(
      store().getObject("a-panel"),
      undefined,
      "but nothing is written"
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
        <DDockPanel @isOpen={{true}}><:body>Content</:body></DDockPanel>
      </template>
    );

    await click(".behind-panel");

    assert.true(clicked, "the click reaches the page");
    assert.dom(".d-dock-panel").exists("the panel is not dismissed");
  });
});
