import { hash } from "@ember/helper";
import { getOwner } from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import {
  click,
  render,
  triggerEvent,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import DButton from "discourse/components/d-button";
import element_ from "discourse/helpers/element";
import { forceMobile } from "discourse/lib/mobile";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DDefaultToast from "float-kit/components/d-default-toast";
import DMenu from "float-kit/components/d-menu";
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
    await render(
      <template><DMenu @inline={{true}} @label="label" /></template>
    );

    assert.dom(".fk-d-menu__trigger .d-button-label").hasText(/^label$/);
  });

  test("@icon", async function (assert) {
    await render(<template><DMenu @inline={{true}} @icon="check" /></template>);

    assert.dom(".fk-d-menu__trigger .d-icon-check").exists();
  });

  test("@content", async function (assert) {
    await render(
      <template>
        <DMenu @inline={{true}} @label="label" @content="content" />
      </template>
    );
    await open();

    assert.dom(".fk-d-menu").hasText("content");
  });

  test("@modalForMobile", async function (assert) {
    forceMobile();

    await render(
      <template>
        <DMenu
          @identifier="foo"
          @inline={{true}}
          @modalForMobile={{true}}
          @content="content"
        />
      </template>
    );
    await open();

    assert.dom(".fk-d-menu-modal[data-identifier='foo']").hasText("content");
  });

  test("@onRegisterApi", async function (assert) {
    const self = this;

    this.api = null;
    this.onRegisterApi = (api) => (this.api = api);

    await render(
      <template>
        <DMenu @inline={{true}} @onRegisterApi={{self.onRegisterApi}} />
      </template>
    );

    assert.true(this.api instanceof DMenuInstance);
  });

  test("@onShow", async function (assert) {
    const self = this;

    this.test = false;
    this.onShow = () => (this.test = true);

    await render(
      <template><DMenu @inline={{true}} @onShow={{self.onShow}} /></template>
    );
    await open();

    assert.true(this.test);
  });

  test("@onClose", async function (assert) {
    const self = this;

    this.test = false;
    this.onClose = () => (this.test = true);

    await render(
      <template><DMenu @inline={{true}} @onClose={{self.onClose}} /></template>
    );
    await open();
    await close();

    assert.true(this.test);
  });

  test("-expanded class", async function (assert) {
    await render(
      <template><DMenu @inline={{true}} @label="label" /></template>
    );

    assert.dom(".fk-d-menu__trigger").doesNotHaveClass("-expanded");

    await open();

    assert.dom(".fk-d-menu__trigger").hasClass("-expanded");
  });

  test("trigger id attribute", async function (assert) {
    await render(
      <template><DMenu @inline={{true}} @label="label" /></template>
    );

    assert.dom(".fk-d-menu__trigger").hasAttribute("id");
  });

  test("@identifier", async function (assert) {
    await render(
      <template>
        <DMenu @inline={{true}} @label="label" @identifier="tip" />
      </template>
    );

    assert.dom(".fk-d-menu__trigger").hasAttribute("data-identifier", "tip");

    await open();

    assert.dom(".fk-d-menu").hasAttribute("data-identifier", "tip");
  });

  test("aria-expanded attribute", async function (assert) {
    await render(
      <template><DMenu @inline={{true}} @label="label" /></template>
    );

    assert.dom(".fk-d-menu__trigger").hasAttribute("aria-expanded", "false");

    await open();

    assert.dom(".fk-d-menu__trigger").hasAttribute("aria-expanded", "true");
  });

  test("<:trigger>", async function (assert) {
    await render(
      <template>
        <DMenu @inline={{true}}><:trigger>label</:trigger></DMenu>
      </template>
    );

    assert.dom(".fk-d-menu__trigger").containsText("label");
  });

  test("<:content>", async function (assert) {
    await render(
      <template>
        <DMenu @inline={{true}}><:content>content</:content></DMenu>
      </template>
    );

    await open();

    assert.dom(".fk-d-menu").containsText("content");
  });

  test("content role attribute", async function (assert) {
    await render(
      <template><DMenu @inline={{true}} @label="label" /></template>
    );

    await open();

    assert.dom(".fk-d-menu").hasAttribute("role", "dialog");
  });

  test("@component", async function (assert) {
    const self = this;

    this.component = DDefaultToast;

    await render(
      <template>
        <DMenu
          @inline={{true}}
          @label="test"
          @component={{self.component}}
          @data={{hash message="content"}}
        />
      </template>
    );

    await open();

    assert.dom(".fk-d-menu").containsText("content");

    await click(".fk-d-menu .btn");

    assert.dom(".fk-d-menu").doesNotExist();
  });

  test("content aria-labelledby attribute", async function (assert) {
    await render(
      <template><DMenu @inline={{true}} @label="label" /></template>
    );

    await open();

    assert.strictEqual(
      document.querySelector(".fk-d-menu__trigger").id,
      document.querySelector(".fk-d-menu").getAttribute("aria-labelledby")
    );
  });

  test("@closeOnEscape", async function (assert) {
    await render(
      <template>
        <DMenu @inline={{true}} @label="label" @closeOnEscape={{true}} />
      </template>
    );
    await open();
    await triggerKeyEvent(document.activeElement, "keydown", "Escape");

    assert.dom(".fk-d-menu").doesNotExist();

    await render(
      <template>
        <DMenu @inline={{true}} @label="label" @closeOnEscape={{false}} />
      </template>
    );
    await open();
    await triggerKeyEvent(document.activeElement, "keydown", "Escape");

    assert.dom(".fk-d-menu").exists();
  });

  test("@closeOnClickOutside", async function (assert) {
    await render(
      <template>
        <span class="test">test</span><DMenu
          @inline={{true}}
          @label="label"
          @closeOnClickOutside={{true}}
        />
      </template>
    );
    await open();
    await triggerEvent(".test", "pointerdown");

    assert.dom(".fk-d-menu").doesNotExist();

    await render(
      <template>
        <span class="test">test</span><DMenu
          @inline={{true}}
          @label="label"
          @closeOnClickOutside={{false}}
        />
      </template>
    );
    await open();
    await triggerEvent(".test", "pointerdown");

    assert.dom(".fk-d-menu").exists();
  });

  test("@maxWidth", async function (assert) {
    await render(
      <template>
        <DMenu @inline={{true}} @label="label" @maxWidth={{20}} />
      </template>
    );
    await open();

    assert.dom(".fk-d-menu").hasStyle({ maxWidth: "20px" });
  });

  test("applies position", async function (assert) {
    await render(
      <template><DMenu @inline={{true}} @label="label" /></template>
    );
    await open();

    assert.dom(".fk-d-menu").hasAttribute("style", /top: [\d.]+?px/);
    assert.dom(".fk-d-menu").hasAttribute("style", /left: [\d.]+?px/);
  });

  test("content close argument", async function (assert) {
    await render(
      <template>
        <DMenu @inline={{true}}><:trigger>test</:trigger><:content
            as |args|
          ><DButton @icon="xmark" @action={{args.close}} /></:content></DMenu>
      </template>
    );
    await open();

    await click(".d-icon-xmark");

    assert.dom(".fk-d-menu").doesNotExist();
  });

  test("@autofocus", async function (assert) {
    await render(
      <template>
        <DMenu @inline={{true}} @autofocus={{true}}>
          <:content>
            <DButton class="my-button" />
          </:content>
        </DMenu>
      </template>
    );
    await open();

    assert.dom(document.activeElement).hasClass("my-button");
  });

  test("a menu can be closed by identifier", async function (assert) {
    await render(
      <template>
        <DMenu @inline={{true}} @identifier="test">test</DMenu>
      </template>
    );
    await open();

    await getOwner(this).lookup("service:menu").close("test");

    assert.dom(".fk-d-menu.test-content").doesNotExist();
  });

  test("get a menu by identifier", async function (assert) {
    await render(
      <template>
        <DMenu @inline={{true}} @identifier="test">test</DMenu>
      </template>
    );
    await open();

    const activeMenu = getOwner(this)
      .lookup("service:menu")
      .getByIdentifier("test");

    await activeMenu.close();

    assert.dom(".fk-d-menu.test-content").doesNotExist();
  });

  test("opening a menu with the same identifier", async function (assert) {
    await render(
      <template>
        <DMenu @inline={{true}} @identifier="foo" @class="first">1</DMenu><DMenu
          @inline={{true}}
          @identifier="foo"
          @class="second"
        >2</DMenu>
      </template>
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
      <template>
        <DMenu
          @inline={{true}}
          @groupIdentifier="foo"
          @class="first"
        >1</DMenu><DMenu
          @inline={{true}}
          @groupIdentifier="foo"
          @class="second"
        >2</DMenu>
      </template>
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
      <template>
        <DMenu @inline={{true}} @class="first">1</DMenu><DMenu
          @inline={{true}}
          @class="second"
        >2</DMenu>
      </template>
    );

    await click(".first.fk-d-menu__trigger");

    assert.dom(".fk-d-menu.first").exists();
    assert.dom(".fk-d-menu.second").doesNotExist();

    await click(".second.fk-d-menu__trigger");

    assert.dom(".fk-d-menu.first").exists("doesn't autoclose");
    assert.dom(".fk-d-menu.second").exists();
  });

  test("@class", async function (assert) {
    await render(
      <template>
        <DMenu @inline={{true}} @class="first">1</DMenu>
      </template>
    );

    await open();

    assert.dom(".fk-d-menu__trigger.first").exists();
    assert.dom(".fk-d-menu.first").exists();
  });

  test("@triggerClass", async function (assert) {
    await render(
      <template>
        <DMenu @inline={{true}} @triggerClass="first">1</DMenu>
      </template>
    );

    await open();

    assert.dom(".fk-d-menu__trigger.first").exists();
    assert.dom(".fk-d-menu.first").doesNotExist();
  });

  test("@contentClass", async function (assert) {
    await render(
      <template>
        <DMenu @inline={{true}} @contentClass="first">1</DMenu>
      </template>
    );

    await open();

    assert.dom(".fk-d-menu__trigger.first").doesNotExist();
    assert.dom(".fk-d-menu.first").exists();
  });

  test("focusTrigger on close", async function (assert) {
    const self = this;

    this.api = null;
    this.onRegisterApi = (api) => (this.api = api);
    this.close = async () => await this.api.close();

    await render(
      <template>
        <DMenu
          @onRegisterApi={{self.onRegisterApi}}
          @inline={{true}}
          @icon="xmark"
        >
          <DButton @icon="xmark" class="close" @action={{self.close}} />
        </DMenu>
      </template>
    );

    await click(".fk-d-menu__trigger");
    await triggerKeyEvent(document.activeElement, "keydown", "Tab");
    await triggerKeyEvent(document.activeElement, "keydown", "Enter");

    assert.dom(".fk-d-menu__trigger").isFocused();
  });

  test("focusTrigger=false on close", async function (assert) {
    const self = this;

    this.api = null;
    this.onRegisterApi = (api) => (this.api = api);
    this.close = async () => await this.api.close({ focusTrigger: false });

    await render(
      <template>
        <DMenu
          @onRegisterApi={{self.onRegisterApi}}
          @inline={{true}}
          @icon="xmark"
        >
          <DButton @icon="xmark" class="close" @action={{self.close}} />
        </DMenu>
      </template>
    );

    await click(".fk-d-menu__trigger");
    await triggerKeyEvent(document.activeElement, "keydown", "Tab");
    await triggerKeyEvent(document.activeElement, "keydown", "Enter");

    assert.dom(document.body).isFocused();
  });

  test("traps pointerdown events only when expanded ", async function (assert) {
    const self = this;

    let propagated = false;

    const listener = () => {
      propagated = true;
    };

    this.didInsert = (element) => {
      element.addEventListener("pointerdown", listener);
    };
    this.willDestroy = (element) => {
      element.removeEventListener("pointerdown", listener);
    };

    await render(
      <template>
        <div {{didInsert self.didInsert}} {{willDestroy self.willDestroy}}>
          <DMenu
            @inline={{true}}
            @label="label"
            @identifier="d-menu-pointerdown-trap-test"
          />
        </div>
      </template>
    );

    await triggerEvent(".d-menu-pointerdown-trap-test-trigger", "pointerdown");

    assert.true(
      propagated,
      "the pointerdown event is propagated to the parent element when the menu isn't expanded"
    );

    propagated = false;

    await open();
    await triggerEvent(".d-menu-pointerdown-trap-test-trigger", "pointerdown");

    assert.false(
      propagated,
      "the pointerdown event isn't propagated to the parent element when the menu is expanded"
    );
  });

  test("@triggerComponent", async function (assert) {
    await render(
      <template>
        <DMenu @inline={{true}} @triggerComponent={{element_ "span"}}>1</DMenu>
      </template>
    );

    await open();

    assert.dom("span.fk-d-menu__trigger").exists();
  });
});
