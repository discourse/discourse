import { getOwner } from "@ember/owner";
import {
  click,
  render,
  triggerEvent,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DDefaultToast from "float-kit/components/d-default-toast";
import DTooltipInstance from "float-kit/lib/d-tooltip-instance";

module("Integration | Component | FloatKit | d-tooltip", function (hooks) {
  setupRenderingTest(hooks);

  async function hover() {
    await triggerEvent(".fk-d-tooltip__trigger", "mousemove");
  }

  async function leave() {
    await triggerEvent(".fk-d-tooltip__trigger", "mouseleave");
  }

  async function close() {
    await triggerKeyEvent(document.activeElement, "keydown", "Escape");
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

    assert.dom(".fk-d-tooltip__content").hasText("content");
  });

  test("@onRegisterApi", async function (assert) {
    this.api = null;
    this.onRegisterApi = (api) => (this.api = api);

    await render(
      hbs`<DTooltip @inline={{true}} @onRegisterApi={{this.onRegisterApi}} />`
    );

    assert.ok(this.api instanceof DTooltipInstance);
  });

  test("@onShow", async function (assert) {
    this.test = false;
    this.onShow = () => (this.test = true);

    await render(hbs`<DTooltip @inline={{true}} @onShow={{this.onShow}} />`);

    await hover();

    assert.strictEqual(this.test, true);
  });

  test("@onClose", async function (assert) {
    this.test = false;
    this.onClose = () => (this.test = true);

    await render(hbs`<DTooltip @inline={{true}} @onClose={{this.onClose}} />`);
    await hover();
    await close();

    assert.strictEqual(this.test, true);
  });

  test("-expanded class", async function (assert) {
    await render(hbs`<DTooltip @inline={{true}} @label="label" />`);

    assert.dom(".fk-d-tooltip__trigger").doesNotHaveClass("-expanded");

    await hover();

    assert.dom(".fk-d-tooltip__trigger").hasClass("-expanded");
  });

  test("trigger role attribute", async function (assert) {
    await render(hbs`<DTooltip @inline={{true}} @label="label" />`);

    assert.dom(".fk-d-tooltip__trigger").hasAttribute("role", "button");
  });

  test("trigger id attribute", async function (assert) {
    await render(hbs`<DTooltip @inline={{true}} @label="label" />`);

    assert.dom(".fk-d-tooltip__trigger").hasAttribute("id");
  });

  test("@identifier", async function (assert) {
    await render(
      hbs`<DTooltip @inline={{true}} @label="label" @identifier="tip" />`
    );

    assert.dom(".fk-d-tooltip__trigger").hasAttribute("data-identifier", "tip");

    await hover();

    assert.dom(".fk-d-tooltip__content").hasAttribute("data-identifier", "tip");
  });

  test("aria-expanded attribute", async function (assert) {
    await render(hbs`<DTooltip @inline={{true}} @label="label" />`);

    assert.dom(".fk-d-tooltip__trigger").hasAttribute("aria-expanded", "false");

    await hover();

    assert.dom(".fk-d-tooltip__trigger").hasAttribute("aria-expanded", "true");
  });

  test("<:trigger>", async function (assert) {
    await render(
      hbs`<DTooltip @inline={{true}}><:trigger>label</:trigger></DTooltip>`
    );

    assert.dom(".fk-d-tooltip__trigger").hasText("label");
  });

  test("<:content>", async function (assert) {
    await render(
      hbs`<DTooltip @inline={{true}}><:content>content</:content></DTooltip>`
    );

    await hover();

    assert.dom(".fk-d-tooltip__content").hasText("content");
  });

  test("content role attribute", async function (assert) {
    await render(hbs`<DTooltip @inline={{true}} @label="label" />`);

    await hover();

    assert.dom(".fk-d-tooltip__content").hasAttribute("role", "tooltip");
  });

  test("@component", async function (assert) {
    this.component = DDefaultToast;

    await render(
      hbs`<DTooltip @inline={{true}} @label="test" @component={{this.component}} @data={{hash message="content"}} />`
    );

    await hover();

    assert.dom(".fk-d-tooltip__content").containsText("content");

    await click(".fk-d-tooltip__content .btn");

    assert.dom(".fk-d-tooltip__content").doesNotExist();
  });

  test("content aria-labelledby attribute", async function (assert) {
    await render(hbs`<DTooltip @inline={{true}} @label="label" />`);

    await hover();

    assert.strictEqual(
      document.querySelector(".fk-d-tooltip__trigger").id,
      document
        .querySelector(".fk-d-tooltip__content")
        .getAttribute("aria-labelledby")
    );
  });

  test("@closeOnEscape", async function (assert) {
    await render(
      hbs`<DTooltip @inline={{true}} @label="label" @closeOnEscape={{true}} />`
    );
    await hover();
    await close();

    assert.dom(".fk-d-tooltip__content").doesNotExist();

    await render(
      hbs`<DTooltip @inline={{true}} @label="label" @closeOnEscape={{false}} />`
    );
    await hover();
    await close();

    assert.dom(".fk-d-tooltip__content").exists();
  });

  test("@closeOnClickOutside", async function (assert) {
    await render(
      hbs`<span class="test">test</span><DTooltip @inline={{true}} @label="label" @closeOnClickOutside={{true}} />`
    );
    await hover();
    await triggerEvent(".test", "pointerdown");

    assert.dom(".fk-d-tooltip__content").doesNotExist();

    await render(
      hbs`<span class="test">test</span><DTooltip @inline={{true}} @label="label" @closeOnClickOutside={{false}} />`
    );
    await hover();
    await triggerEvent(".test", "pointerdown");

    assert.dom(".fk-d-tooltip__content").exists();
  });

  test("@maxWidth", async function (assert) {
    await render(
      hbs`<DTooltip @inline={{true}} @label="label" @maxWidth={{20}} />`
    );
    await hover();

    assert
      .dom(".fk-d-tooltip__content")
      .hasAttribute("style", /max-width: 20px;/);
  });

  test("applies position", async function (assert) {
    await render(hbs`<DTooltip @inline={{true}} @label="label" />`);
    await hover();

    assert.dom(".fk-d-tooltip__content").hasAttribute("style", /left: /);
    assert.dom(".fk-d-tooltip__content").hasAttribute("style", /top: /);
  });

  test("a tooltip can be closed by identifier", async function (assert) {
    await render(
      hbs`<DTooltip @inline={{true}} @label="label" @identifier="test">test</DTooltip>`
    );
    await hover();

    await getOwner(this).lookup("service:tooltip").close("test");

    assert.dom(".fk-d-tooltip__content.test-content").doesNotExist();
  });

  test("a tooltip is triggered/untriggered by click on mobile", async function (assert) {
    this.site.mobileView = true;

    await render(hbs`<DTooltip @inline={{true}} @label="label" />`);
    await click(".fk-d-tooltip__trigger");

    assert.dom(".fk-d-tooltip__content").exists();

    await click(".fk-d-tooltip__trigger");

    assert.dom(".fk-d-tooltip__content").doesNotExist();
  });

  test("a tooltip is triggered/untriggered by click on desktop", async function (assert) {
    await render(hbs`<DTooltip @inline={{true}} @label="label" />`);
    await click(".fk-d-tooltip__trigger");

    assert.dom(".fk-d-tooltip__content").exists();

    await click(".fk-d-tooltip__trigger");

    assert.dom(".fk-d-tooltip__content").doesNotExist();
  });

  test("a tooltip is triggered/untriggered by hover on desktop", async function (assert) {
    await render(hbs`<DTooltip @inline={{true}} @label="label" />`);

    await hover();

    assert.dom(".fk-d-tooltip__content").exists();

    await leave();

    assert.dom(".fk-d-tooltip__content").doesNotExist();
  });
});
