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

module("Integration | Component | FloatKit | d-menu", function (hooks) {
  setupRenderingTest(hooks);

  async function open() {
    await triggerEvent(".fk-d-menu__trigger", "click");
  }

  test("@label", async function (assert) {
    await render(hbs`<DMenu @inline={{true}} @label="label" />`);

    assert.dom(".fk-d-menu__trigger").containsText("label");
  });

  test("@icon", async function (assert) {
    await render(hbs`<DMenu @inline={{true}} @icon="check" />`);

    assert.dom(".fk-d-menu__trigger .d-icon-check").exists();
  });

  test("@content", async function (assert) {
    await render(
      hbs`<DMenu @inline={{true}} @label="label" @content="content" />`
    );
    await open();

    assert.dom(".fk-d-menu").hasText("content");
  });

  test("-expanded class", async function (assert) {
    await render(hbs`<DMenu @inline={{true}} @label="label"  />`);

    assert.dom(".fk-d-menu__trigger").doesNotHaveClass("-expanded");

    await open();

    assert.dom(".fk-d-menu__trigger").hasClass("-expanded");
  });

  test("trigger id attribute", async function (assert) {
    await render(hbs`<DMenu @inline={{true}} @label="label"  />`);

    assert.dom(".fk-d-menu__trigger").hasAttribute("id");
  });

  test("@identifier", async function (assert) {
    await render(
      hbs`<DMenu @inline={{true}} @label="label" @identifier="tip" />`
    );

    assert.dom(".fk-d-menu__trigger").hasAttribute("data-identifier", "tip");

    await open();

    assert.dom(".fk-d-menu").hasAttribute("data-identifier", "tip");
  });

  test("aria-expanded attribute", async function (assert) {
    await render(hbs`<DMenu @inline={{true}} @label="label"  />`);

    assert.dom(".fk-d-menu__trigger").hasAttribute("aria-expanded", "false");

    await open();

    assert.dom(".fk-d-menu__trigger").hasAttribute("aria-expanded", "true");
  });

  test("<:trigger>", async function (assert) {
    await render(
      hbs`<DMenu @inline={{true}}><:trigger>label</:trigger></DMenu />`
    );

    assert.dom(".fk-d-menu__trigger").containsText("label");
  });

  test("<:content>", async function (assert) {
    await render(
      hbs`<DMenu @inline={{true}}><:content>content</:content></DMenu />`
    );

    await open();

    assert.dom(".fk-d-menu").containsText("content");
  });

  test("content role attribute", async function (assert) {
    await render(hbs`<DMenu @inline={{true}} @label="label"  />`);

    await open();

    assert.dom(".fk-d-menu").hasAttribute("role", "dialog");
  });

  test("@component", async function (assert) {
    this.component = DDefaultToast;

    await render(
      hbs`<DMenu @inline={{true}} @label="test" @component={{this.component}} @data={{hash message="content"}}/>`
    );

    await open();

    assert.dom(".fk-d-menu").containsText("content");

    await click(".fk-d-menu .btn");

    assert.dom(".fk-d-menu").doesNotExist();
  });

  test("content aria-labelledby attribute", async function (assert) {
    await render(hbs`<DMenu @inline={{true}} @label="label"  />`);

    await open();

    assert.strictEqual(
      document.querySelector(".fk-d-menu__trigger").id,
      document.querySelector(".fk-d-menu").getAttribute("aria-labelledby")
    );
  });

  test("@closeOnEscape", async function (assert) {
    await render(
      hbs`<DMenu @inline={{true}} @label="label" @closeOnEscape={{true}}  />`
    );
    await open();
    await triggerKeyEvent(document.activeElement, "keydown", "Escape");

    assert.dom(".fk-d-menu").doesNotExist();

    await render(
      hbs`<DMenu @inline={{true}} @label="label" @closeOnEscape={{false}}  />`
    );
    await open();
    await triggerKeyEvent(document.activeElement, "keydown", "Escape");

    assert.dom(".fk-d-menu").exists();
  });

  test("@closeOnClickOutside", async function (assert) {
    await render(
      hbs`<span class="test">test</span><DMenu @inline={{true}} @label="label" @closeOnClickOutside={{true}}  />`
    );
    await open();
    await click(".test");

    assert.dom(".fk-d-menu").doesNotExist();

    await render(
      hbs`<span class="test">test</span><DMenu @inline={{true}} @label="label" @closeOnClickOutside={{false}}  />`
    );
    await open();
    await click(".test");

    assert.dom(".fk-d-menu").exists();
  });

  test("@maxWidth", async function (assert) {
    await render(
      hbs`<DMenu @inline={{true}} @label="label" @maxWidth={{20}}  />`
    );
    await open();

    assert.ok(
      find(".fk-d-menu").getAttribute("style").includes("max-width: 20px;")
    );
  });

  test("applies position", async function (assert) {
    await render(hbs`<DMenu @inline={{true}} @label="label"  />`);
    await open();

    assert.dom(".fk-d-menu").hasAttribute("style", /left: /);
    assert.ok(find(".fk-d-menu").getAttribute("style").includes("top: "));
  });
});
