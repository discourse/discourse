import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  click,
  find,
  render,
  triggerEvent,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import DDefaultToast from "float-kit/components/d-default-toast";

module("Integration | Component | FloatKit | d-tooltip", function (hooks) {
  setupRenderingTest(hooks);

  async function hover() {
    await triggerEvent(".fk-d-tooltip__trigger", "mousemove");
  }

  test("@label", async function (assert) {
    await render(hbs`<DTooltip @inline={{true}} @label="label" />`);

    assert.dom(".fk-d-tooltip__label").hasText("label");
  });

  test("@icon", async function (assert) {
    await render(hbs`<DTooltip @inline={{true}} @icon="check" />`);

    assert.dom(".fk-d-tooltip__icon .d-icon-check").exists();
  });

  test("@content", async function (assert) {
    await render(
      hbs`<DTooltip @inline={{true}} @label="label" @content="content" />`
    );
    await hover();

    assert.dom(".fk-d-tooltip").hasText("content");
  });

  test("-expanded class", async function (assert) {
    await render(hbs`<DTooltip @inline={{true}} @label="label"  />`);

    assert.dom(".fk-d-tooltip__trigger").doesNotHaveClass("-expanded");

    await hover();

    assert.dom(".fk-d-tooltip__trigger").hasClass("-expanded");
  });

  test("trigger role attribute", async function (assert) {
    await render(hbs`<DTooltip @inline={{true}} @label="label"  />`);

    assert.dom(".fk-d-tooltip__trigger").hasAttribute("role", "button");
  });

  test("trigger id attribute", async function (assert) {
    await render(hbs`<DTooltip @inline={{true}} @label="label"  />`);

    assert.dom(".fk-d-tooltip__trigger").hasAttribute("id");
  });

  test("@identifier", async function (assert) {
    await render(
      hbs`<DTooltip @inline={{true}} @label="label" @identifier="tip" />`
    );

    assert.dom(".fk-d-tooltip__trigger").hasAttribute("data-identifier", "tip");

    await hover();

    assert.dom(".fk-d-tooltip").hasAttribute("data-identifier", "tip");
  });

  test("aria-expanded attribute", async function (assert) {
    await render(hbs`<DTooltip @inline={{true}} @label="label"  />`);

    assert.dom(".fk-d-tooltip__trigger").hasAttribute("aria-expanded", "false");

    await hover();

    assert.dom(".fk-d-tooltip__trigger").hasAttribute("aria-expanded", "true");
  });

  test("<:trigger>", async function (assert) {
    await render(
      hbs`<DTooltip @inline={{true}}><:trigger>label</:trigger></DTooltip />`
    );

    assert.dom(".fk-d-tooltip__trigger").hasText("label");
  });

  test("<:content>", async function (assert) {
    await render(
      hbs`<DTooltip @inline={{true}}><:content>content</:content></DTooltip />`
    );

    await hover();

    assert.dom(".fk-d-tooltip").hasText("content");
  });

  test("content role attribute", async function (assert) {
    await render(hbs`<DTooltip @inline={{true}} @label="label"  />`);

    await hover();

    assert.dom(".fk-d-tooltip").hasAttribute("role", "tooltip");
  });

  test("@component", async function (assert) {
    this.component = DDefaultToast;

    await render(
      hbs`<DTooltip @inline={{true}} @label="test" @component={{this.component}} @data={{hash message="content"}} />`
    );

    await hover();

    assert.dom(".fk-d-tooltip").containsText("content");

    await click(".fk-d-tooltip .btn");

    assert.dom(".fk-d-tooltip").doesNotExist();
  });

  test("content aria-labelledby attribute", async function (assert) {
    await render(hbs`<DTooltip @inline={{true}} @label="label"  />`);

    await hover();

    assert.strictEqual(
      document.querySelector(".fk-d-tooltip__trigger").id,
      document.querySelector(".fk-d-tooltip").getAttribute("aria-labelledby")
    );
  });

  test("@closeOnEscape", async function (assert) {
    await render(
      hbs`<DTooltip @inline={{true}} @label="label" @closeOnEscape={{true}} />`
    );
    await hover();
    await triggerKeyEvent(document.activeElement, "keydown", "Escape");

    assert.dom(".fk-d-tooltip").doesNotExist();

    await render(
      hbs`<DTooltip @inline={{true}} @label="label" @closeOnEscape={{false}} />`
    );
    await hover();
    await triggerKeyEvent(document.activeElement, "keydown", "Escape");

    assert.dom(".fk-d-tooltip").exists();
  });

  test("@closeOnClickOutside", async function (assert) {
    await render(
      hbs`<span class="test">test</span><DTooltip @inline={{true}} @label="label" @closeOnClickOutside={{true}} />`
    );
    await hover();
    await click(".test");

    assert.dom(".fk-d-tooltip").doesNotExist();

    await render(
      hbs`<span class="test">test</span><DTooltip @inline={{true}} @label="label" @closeOnClickOutside={{false}} />`
    );
    await hover();
    await click(".test");

    assert.dom(".fk-d-tooltip").exists();
  });

  test("@maxWidth", async function (assert) {
    await render(
      hbs`<DTooltip @inline={{true}} @label="label" @maxWidth={{20}} />`
    );
    await hover();

    assert.ok(
      find(".fk-d-tooltip").getAttribute("style").includes("max-width: 20px;")
    );
  });

  test("applies position", async function (assert) {
    await render(hbs`<DTooltip @inline={{true}} @label="label"  />`);
    await hover();

    assert.ok(find(".fk-d-tooltip").getAttribute("style").includes("left: "));
    assert.ok(find(".fk-d-tooltip").getAttribute("style").includes("top: "));
  });
});
