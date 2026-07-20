import { array, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { getOwner } from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import {
  click,
  find,
  render,
  rerender,
  settled,
  triggerEvent,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import ModalContainer from "discourse/components/modal-container";
import DDefaultToast from "discourse/float-kit/components/d-default-toast";
import DMenu from "discourse/float-kit/components/d-menu";
import DMenus from "discourse/float-kit/components/d-menus";
import DTooltips from "discourse/float-kit/components/d-tooltips";
import DMenuInstance from "discourse/float-kit/lib/d-menu-instance";
import { forceMobile } from "discourse/lib/mobile";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DButton from "discourse/ui-kit/d-button";
import dElement from "discourse/ui-kit/helpers/d-element";

module("Integration | Component | FloatKit | DMenu", function (hooks) {
  setupRenderingTest(hooks);

  async function open() {
    await triggerEvent(".fk-d-menu__trigger", "click");
  }

  async function close() {
    await triggerEvent(".fk-d-menu__trigger.-expanded", "click");
  }

  async function swipeDown(selector) {
    await triggerEvent(selector, "touchstart", {
      touches: [{ clientX: 0, clientY: 0 }],
      changedTouches: [{ clientX: 0, clientY: 0 }],
    });
    await triggerEvent(selector, "touchmove", {
      touches: [{ clientX: 0, clientY: 200 }],
      changedTouches: [{ clientX: 0, clientY: 200 }],
    });
    await triggerEvent(selector, "touchend", {
      touches: [],
      changedTouches: [{ clientX: 0, clientY: 200 }],
    });
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

  test("DMenu uses a modal while DTooltip stays inline on mobile", async function (assert) {
    forceMobile();

    await render(
      <template>
        <div class="menu-trigger"></div>
        <div class="tooltip-trigger"></div>
        <DMenus />
        <DTooltips />
        <ModalContainer />
      </template>
    );

    const menu = await getOwner(this)
      .lookup("service:menu")
      .show(find(".menu-trigger"), {
        content: "menu content",
        identifier: "mobile-menu",
        modalForMobile: true,
      });
    const tooltip = await getOwner(this)
      .lookup("service:tooltip")
      .show(find(".tooltip-trigger"), {
        content: "tooltip content",
        identifier: "mobile-tooltip",
      });
    await settled();

    assert.true(menu.renderInModal, "the menu instance selects the modal path");
    assert.false(
      tooltip.renderInModal,
      "the tooltip instance keeps the default inline path"
    );
    assert
      .dom(".fk-d-menu-modal")
      .hasText("menu content", "the menu renders in a modal");
    assert
      .dom(".fk-d-tooltip__content[data-identifier='mobile-tooltip']")
      .hasText("tooltip content", "the tooltip renders as an inline float");
  });

  test("@modalForMobile - swipe down to close", async function (assert) {
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

    assert.dom(".fk-d-menu-modal").exists();

    await swipeDown(".fk-d-menu-modal .d-modal__container");

    assert.dom(".fk-d-menu-modal").doesNotExist();
  });

  test("@modalForMobile - swipe down defers to scrolled content", async function (assert) {
    forceMobile();

    await render(
      <template>
        <DMenu @identifier="foo" @inline={{true}} @modalForMobile={{true}}>
          <div class="test-scroll-area" style="height: 50px; overflow-y: auto">
            <div style="height: 500px">tall content</div>
          </div>
        </DMenu>
      </template>
    );
    await open();

    document.querySelector(".test-scroll-area").scrollTop = 100;

    await swipeDown(".test-scroll-area");

    assert.dom(".fk-d-menu-modal").exists();
  });

  test("@onRegisterApi", async function (assert) {
    this.api = null;
    this.onRegisterApi = (api) => (this.api = api);

    await render(
      <template>
        <DMenu @inline={{true}} @onRegisterApi={{this.onRegisterApi}} />
      </template>
    );

    assert.true(this.api instanceof DMenuInstance);
  });

  test("@onShow", async function (assert) {
    this.test = false;
    this.onShow = () => (this.test = true);

    await render(
      <template><DMenu @inline={{true}} @onShow={{this.onShow}} /></template>
    );
    await open();

    assert.true(this.test);
  });

  test("@onClose", async function (assert) {
    this.test = false;
    this.onClose = () => (this.test = true);

    await render(
      <template><DMenu @inline={{true}} @onClose={{this.onClose}} /></template>
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
    this.component = DDefaultToast;

    await render(
      <template>
        <DMenu
          @inline={{true}}
          @label="test"
          @component={{this.component}}
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

  test("trigger expanded argument reflects the open state", async function (assert) {
    await render(
      <template>
        <DMenu @inline={{true}}>
          <:trigger as |args|>
            <span class="expanded-flag">{{if
                args.expanded
                "open"
                "closed"
              }}</span>
          </:trigger>
          <:content>content</:content>
        </DMenu>
      </template>
    );

    assert
      .dom(".expanded-flag")
      .hasText("closed", "expanded is false when closed");

    await open();
    assert
      .dom(".expanded-flag")
      .hasText("open", "expanded flips to true on open");
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
    this.api = null;
    this.onRegisterApi = (api) => (this.api = api);
    this.close = async () => await this.api.close();

    await render(
      <template>
        <DMenu
          @onRegisterApi={{this.onRegisterApi}}
          @inline={{true}}
          @icon="xmark"
        >
          <DButton @icon="xmark" class="close" @action={{this.close}} />
        </DMenu>
      </template>
    );

    await click(".fk-d-menu__trigger");
    await triggerKeyEvent(document.activeElement, "keydown", "Tab");
    await triggerKeyEvent(document.activeElement, "keydown", "Enter");

    assert.dom(".fk-d-menu__trigger").isFocused();
  });

  test("focusTrigger=false on close", async function (assert) {
    this.api = null;
    this.onRegisterApi = (api) => (this.api = api);
    this.close = async () => await this.api.close({ focusTrigger: false });

    await render(
      <template>
        <DMenu
          @onRegisterApi={{this.onRegisterApi}}
          @inline={{true}}
          @icon="xmark"
        >
          <DButton @icon="xmark" class="close" @action={{this.close}} />
        </DMenu>
      </template>
    );

    await click(".fk-d-menu__trigger");
    await triggerKeyEvent(document.activeElement, "keydown", "Tab");
    await triggerKeyEvent(document.activeElement, "keydown", "Enter");

    assert.dom(document.body).isFocused();
  });

  test("traps pointerdown events only when expanded ", async function (assert) {
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
        <div {{didInsert this.didInsert}} {{willDestroy this.willDestroy}}>
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
        <DMenu @inline={{true}} @triggerComponent={{dElement "span"}}>1</DMenu>
      </template>
    );

    await open();

    assert.dom("span.fk-d-menu__trigger").exists();
  });

  test("@disabled blocks a custom trigger and updates reactively", async function (assert) {
    this.disabled = true;

    await render(
      <template>
        <DMenu
          @disabled={{this.disabled}}
          @inline={{true}}
          @triggerComponent={{dElement "div"}}
          @content="content"
        />
      </template>
    );

    await click(".fk-d-menu__trigger");
    assert
      .dom(".fk-d-menu")
      .doesNotExist("a custom trigger cannot open while disabled");

    this.set("disabled", false);
    await click(".fk-d-menu__trigger");
    assert
      .dom(".fk-d-menu")
      .exists("clearing disabled after mount restores trigger opening");

    await click(".fk-d-menu__trigger");
    this.set("disabled", true);
    await click(".fk-d-menu__trigger");
    assert
      .dom(".fk-d-menu")
      .doesNotExist("setting disabled after mount re-gates trigger opening");
  });

  test("@disabled blocks the default button trigger", async function (assert) {
    await render(
      <template>
        <DMenu
          @disabled={{true}}
          @inline={{true}}
          @label="label"
          @content="content"
        />
      </template>
    );

    assert
      .dom(".fk-d-menu__trigger")
      .isDisabled("the default trigger retains its native disabled state");

    find(".fk-d-menu__trigger").dispatchEvent(
      new MouseEvent("click", { bubbles: true })
    );
    await settled();
    assert
      .dom(".fk-d-menu")
      .doesNotExist("the default trigger cannot open while disabled");
  });

  test("disabled delayed-hover does not swallow the first click after re-enabling", async function (assert) {
    this.disabled = true;

    await render(
      <template>
        <DMenu
          @disabled={{this.disabled}}
          @inline={{true}}
          @triggerComponent={{dElement "div"}}
          @triggers={{array "delayed-hover" "click"}}
          @content="content"
        />
      </template>
    );

    triggerEvent(".fk-d-menu__trigger", "pointerenter");
    await settled();
    assert
      .dom(".fk-d-menu")
      .doesNotExist("disabled vetoes the delayed-hover open");

    this.set("disabled", false);
    await click(".fk-d-menu__trigger");
    assert
      .dom(".fk-d-menu")
      .exists("the first click after re-enabling opens the menu");
  });

  test("disabling during beforeTrigger vetoes the pending open", async function (assert) {
    this.disabled = false;
    this.beforeTrigger = () =>
      new Promise((resolve) => (this.resolveBeforeTrigger = resolve));

    await render(
      <template>
        <DMenu
          @beforeTrigger={{this.beforeTrigger}}
          @disabled={{this.disabled}}
          @inline={{true}}
          @triggerComponent={{dElement "div"}}
          @content="content"
        />
      </template>
    );

    find(".fk-d-menu__trigger").dispatchEvent(
      new MouseEvent("click", { bubbles: true })
    );
    this.set("disabled", true);
    await rerender();
    this.resolveBeforeTrigger();
    await settled();

    assert
      .dom(".fk-d-menu")
      .doesNotExist(
        "a pending trigger cannot open after the menu becomes disabled"
      );
  });

  test("a disabled trigger still consumes its click (does not fall through to a clickable ancestor)", async function (assert) {
    let ancestorClicks = 0;
    const onAncestorClick = () => ancestorClicks++;

    await render(
      <template>
        {{! eslint-disable ember/template-no-invalid-interactive }}
        <div {{on "click" onAncestorClick}}>
          <DMenu
            @disabled={{true}}
            @inline={{true}}
            @triggerComponent={{dElement "div"}}
            @content="content"
          />
        </div>
      </template>
    );

    await click(".fk-d-menu__trigger");

    assert.dom(".fk-d-menu").doesNotExist("the disabled menu does not open");
    assert.strictEqual(
      ancestorClicks,
      0,
      "the disabled trigger consumes the click instead of activating its ancestor"
    );
  });

  test("@matchTriggerWidth", async function (assert) {
    await render(
      <template>
        <DMenu
          @label="a long label"
          @inline={{true}}
          @matchTriggerWidth={{true}}
          style="width: 200px;"
        >1</DMenu>
      </template>
    );

    await open();

    assert.dom(".fk-d-menu.-content").hasStyle({
      width: "200px",
    });
  });

  test("delayed-hover opens menu after delay", async function (assert) {
    await render(
      <template>
        <DMenu
          @inline={{true}}
          @label="label"
          @triggers={{array "delayed-hover"}}
          @content="content"
        />
      </template>
    );

    triggerEvent(".fk-d-menu__trigger", "pointerenter");
    assert.dom(".fk-d-menu").doesNotExist("menu not open before delay");

    await settled();

    assert.dom(".fk-d-menu").exists("menu opens after delay");
  });

  test("delayed-hover cancels when pointer leaves before delay", async function (assert) {
    await render(
      <template>
        <DMenu
          @inline={{true}}
          @label="label"
          @triggers={{array "delayed-hover"}}
          @content="content"
        />
      </template>
    );

    triggerEvent(".fk-d-menu__trigger", "pointerenter");
    await triggerEvent(".fk-d-menu__trigger", "pointerleave");

    assert.dom(".fk-d-menu").doesNotExist("menu does not open after leave");
  });

  test("delayed-hover click during pending delay opens menu", async function (assert) {
    await render(
      <template>
        <DMenu
          @inline={{true}}
          @label="label"
          @triggers={{array "delayed-hover" "click"}}
          @content="content"
        />
      </template>
    );

    triggerEvent(".fk-d-menu__trigger", "pointerenter");
    await click(".fk-d-menu__trigger");

    assert
      .dom(".fk-d-menu")
      .exists("menu opens via click during pending hover");
  });

  test("@matchTriggerMinWidth", async function (assert) {
    await render(
      <template>
        <DMenu
          @label="a long label"
          @inline={{true}}
          @matchTriggerMinWidth={{true}}
          style="width: 200px;"
        >1</DMenu>
      </template>
    );

    await open();

    assert.dom(".fk-d-menu.-content").hasStyle({
      minWidth: "200px",
    });
  });
});
