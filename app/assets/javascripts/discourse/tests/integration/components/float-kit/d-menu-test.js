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
import DMenuInstance from "float-kit/lib/d-menu-instance";

module("Integration | Component | FloatKit | d-menu", function (hooks) {
  setupRenderingTest(hooks);

  async function open() {
    await triggerEvent(".fk-d-menu__trigger", "click");
  }

  async function close() {
    await triggerEvent(".fk-d-menu__trigger.-expanded", "click");
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

  test("@modalForMobile", async function (assert) {
    this.site.mobileView = true;

    await render(
      hbs`<DMenu @inline={{true}} @modalForMobile={{true}} @content="content" />`
    );
    await open();

    assert.dom(".fk-d-menu-modal").hasText("content");
  });

  test("@onRegisterApi", async function (assert) {
    this.api = null;
    this.onRegisterApi = (api) => (this.api = api);

    await render(
      hbs`<DMenu @inline={{true}} @onRegisterApi={{this.onRegisterApi}} />`
    );

    assert.true(this.api instanceof DMenuInstance);
  });

  test("@onShow", async function (assert) {
    this.test = false;
    this.onShow = () => (this.test = true);

    await render(hbs`<DMenu @inline={{true}} @onShow={{this.onShow}} />`);
    await open();

    assert.true(this.test);
  });

  test("@onClose", async function (assert) {
    this.test = false;
    this.onClose = () => (this.test = true);

    await render(hbs`<DMenu @inline={{true}} @onClose={{this.onClose}} />`);
    await open();
    await close();

    assert.true(this.test);
  });

  test("-expanded class", async function (assert) {
    await render(hbs`<DMenu @inline={{true}} @label="label" />`);

    assert.dom(".fk-d-menu__trigger").doesNotHaveClass("-expanded");

    await open();

    assert.dom(".fk-d-menu__trigger").hasClass("-expanded");
  });

  test("trigger id attribute", async function (assert) {
    await render(hbs`<DMenu @inline={{true}} @label="label" />`);

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
    await render(hbs`<DMenu @inline={{true}} @label="label" />`);

    assert.dom(".fk-d-menu__trigger").hasAttribute("aria-expanded", "false");

    await open();

    assert.dom(".fk-d-menu__trigger").hasAttribute("aria-expanded", "true");
  });

  test("<:trigger>", async function (assert) {
    await render(
      hbs`<DMenu @inline={{true}}><:trigger>label</:trigger></DMenu>`
    );

    assert.dom(".fk-d-menu__trigger").containsText("label");
  });

  test("<:content>", async function (assert) {
    await render(
      hbs`<DMenu @inline={{true}}><:content>content</:content></DMenu>`
    );

    await open();

    assert.dom(".fk-d-menu").containsText("content");
  });

  test("content role attribute", async function (assert) {
    await render(hbs`<DMenu @inline={{true}} @label="label" />`);

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
    await render(hbs`<DMenu @inline={{true}} @label="label" />`);

    await open();

    assert.strictEqual(
      document.querySelector(".fk-d-menu__trigger").id,
      document.querySelector(".fk-d-menu").getAttribute("aria-labelledby")
    );
  });

  test("@closeOnEscape", async function (assert) {
    await render(
      hbs`<DMenu @inline={{true}} @label="label" @closeOnEscape={{true}} />`
    );
    await open();
    await triggerKeyEvent(document.activeElement, "keydown", "Escape");

    assert.dom(".fk-d-menu").doesNotExist();

    await render(
      hbs`<DMenu @inline={{true}} @label="label" @closeOnEscape={{false}} />`
    );
    await open();
    await triggerKeyEvent(document.activeElement, "keydown", "Escape");

    assert.dom(".fk-d-menu").exists();
  });

  test("@closeOnClickOutside", async function (assert) {
    await render(
      hbs`<span class="test">test</span><DMenu @inline={{true}} @label="label" @closeOnClickOutside={{true}} />`
    );
    await open();
    await triggerEvent(".test", "pointerdown");

    assert.dom(".fk-d-menu").doesNotExist();

    await render(
      hbs`<span class="test">test</span><DMenu @inline={{true}} @label="label" @closeOnClickOutside={{false}} />`
    );
    await open();
    await triggerEvent(".test", "pointerdown");

    assert.dom(".fk-d-menu").exists();
  });

  test("@maxWidth", async function (assert) {
    await render(
      hbs`<DMenu @inline={{true}} @label="label" @maxWidth={{20}} />`
    );
    await open();

    assert.dom(".fk-d-menu").hasStyle({ maxWidth: "20px" });
  });

  test("applies position", async function (assert) {
    await render(hbs`<DMenu @inline={{true}} @label="label" />`);
    await open();

    assert.dom(".fk-d-menu").hasAttribute("style", /top: [\d.]+?px/);
    assert.dom(".fk-d-menu").hasAttribute("style", /left: [\d.]+?px/);
  });

  test("content close argument", async function (assert) {
    await render(
      hbs`<DMenu @inline={{true}}><:trigger>test</:trigger><:content as |args|><DButton @icon="xmark" @action={{args.close}} /></:content></DMenu>`
    );
    await open();

    await click(".d-icon-xmark");

    assert.dom(".fk-d-menu").doesNotExist();
  });

  test("@autofocus", async function (assert) {
    await render(hbs`
      <DMenu @inline={{true}} @autofocus={{true}}>
        <:content>
          <DButton class="my-button" />
        </:content>
      </DMenu>
    `);
    await open();

    assert.dom(document.activeElement).hasClass("my-button");
  });

  test("a menu can be closed by identifier", async function (assert) {
    await render(hbs`<DMenu @inline={{true}} @identifier="test">test</DMenu>`);
    await open();

    await getOwner(this).lookup("service:menu").close("test");

    assert.dom(".fk-d-menu.test-content").doesNotExist();
  });

  test("get a menu by identifier", async function (assert) {
    await render(hbs`<DMenu @inline={{true}} @identifier="test">test</DMenu>`);
    await open();

    const activeMenu = getOwner(this)
      .lookup("service:menu")
      .getByIdentifier("test");

    await activeMenu.close();

    assert.dom(".fk-d-menu.test-content").doesNotExist();
  });

  test("opening a menu with the same identifier", async function (assert) {
    await render(
      hbs`<DMenu @inline={{true}} @identifier="foo" @class="first">1</DMenu><DMenu @inline={{true}} @identifier="foo" @class="second">2</DMenu>`
    );

    await click(".first.fk-d-menu__trigger");

    assert.dom(".foo-content.first").exists();
    assert.dom(".foo-content.second").doesNotExist();

    await click(".second.fk-d-menu__trigger");

    assert.dom(".foo-content.first").doesNotExist();
    assert.dom(".foo-content.second").exists();
  });

  test("@groupIdentifier", async function (assert) {
    await render(
      hbs`<DMenu @inline={{true}} @groupIdentifier="foo" @class="first">1</DMenu><DMenu @inline={{true}} @groupIdentifier="foo" @class="second">2</DMenu>`
    );

    await click(".first.fk-d-menu__trigger");

    assert.dom(".fk-d-menu.first").exists();
    assert.dom(".fk-d-menu.second").doesNotExist();

    await click(".second.fk-d-menu__trigger");

    assert.dom(".fk-d-menu.first").doesNotExist();
    assert.dom(".fk-d-menu.second").exists();
  });

  test("empty @identifier/@groupIdentifier", async function (assert) {
    await render(
      hbs`<DMenu @inline={{true}} @class="first">1</DMenu><DMenu @inline={{true}} @class="second">2</DMenu>`
    );

    await click(".first.fk-d-menu__trigger");

    assert.dom(".fk-d-menu.first").exists();
    assert.dom(".fk-d-menu.second").doesNotExist();

    await click(".second.fk-d-menu__trigger");

    assert.dom(".fk-d-menu.first").exists("doesn’t autoclose");
    assert.dom(".fk-d-menu.second").exists();
  });

  test("@class", async function (assert) {
    await render(hbs`<DMenu @inline={{true}} @class="first">1</DMenu>`);

    await open();

    assert.dom(".fk-d-menu__trigger.first").exists();
    assert.dom(".fk-d-menu.first").exists();
  });

  test("@triggerClass", async function (assert) {
    await render(hbs`<DMenu @inline={{true}} @triggerClass="first">1</DMenu>`);

    await open();

    assert.dom(".fk-d-menu__trigger.first").exists();
    assert.dom(".fk-d-menu.first").doesNotExist();
  });

  test("@contentClass", async function (assert) {
    await render(hbs`<DMenu @inline={{true}} @contentClass="first">1</DMenu>`);

    await open();

    assert.dom(".fk-d-menu__trigger.first").doesNotExist();
    assert.dom(".fk-d-menu.first").exists();
  });
});
