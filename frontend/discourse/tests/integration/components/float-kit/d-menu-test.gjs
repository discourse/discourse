import { array, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { getOwner } from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import {
  click,
  find,
  focus,
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
import { stubPointerCapture } from "discourse/tests/helpers/ui-kit/pointer-gesture-helper";
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
    stubPointerCapture(selector);
    await triggerEvent(selector, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientY: 0,
    });
    await triggerEvent(selector, "pointermove", { pointerId: 1, clientY: 200 });
    await triggerEvent(selector, "pointerup", { pointerId: 1, clientY: 200 });
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

  test("menu.shouldRenderInModal decides without an instance", async function (assert) {
    forceMobile();

    await render(<template><DMenus /></template>);
    const menu = getOwner(this).lookup("service:menu");

    assert.true(
      menu.shouldRenderInModal(true),
      "mobile plus modalForMobile renders in a modal"
    );
    assert.false(
      menu.shouldRenderInModal(false),
      "mobile alone does not render in a modal"
    );
    assert.false(
      menu.shouldRenderInModal(),
      "an omitted option does not render in a modal"
    );
  });

  test("@onPositioned fires with the content once the float is positioned", async function (assert) {
    const positioned = [];
    this.onPositioned = (element) => positioned.push(element);

    await render(
      <template>
        <DMenu
          @inline={{true}}
          @label="label"
          @content="content"
          @onPositioned={{this.onPositioned}}
        />
      </template>
    );

    assert.strictEqual(
      positioned.length,
      0,
      "nothing is positioned while the menu is closed"
    );

    await open();

    assert.true(positioned.length > 0, "opening positions the float");
    assert.dom(positioned[0]).hasClass("fk-d-menu", "the content is passed");
  });

  test("@onPositioned fires when the menu renders as a mobile modal", async function (assert) {
    forceMobile();

    const positioned = [];
    this.onPositioned = (element) => positioned.push(element);

    await render(
      <template>
        <DMenu
          @inline={{true}}
          @modalForMobile={{true}}
          @label="label"
          @content="content"
          @onPositioned={{this.onPositioned}}
        />
      </template>
    );
    await open();

    assert.dom(".fk-d-menu-modal").exists("the menu renders as a modal");
    assert.strictEqual(
      positioned.length,
      1,
      "the modal path reports once, since a modal does not reposition"
    );
    assert
      .dom(positioned[0])
      .hasClass("d-modal", "the modal element is passed");
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

  test("@modalForMobile - leaves content panning to the browser", async function (assert) {
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

    // scroll deferral is the browser's own pan arbitration, which synthetic
    // events cannot trigger; the touch-action wiring it rides on is observable
    assert
      .dom(".fk-d-menu-modal .d-modal__container")
      .hasAttribute(
        "data-pointer-drag",
        "pan-x",
        "vertical pans over scrollable content stay with the browser"
      );
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
    assert
      .dom(".fk-d-menu")
      .doesNotHaveAttribute(
        "aria-expanded",
        "the content carries no expanded state — no role it takes supports one, it could only ever be true while rendered, and the trigger already carries it"
      );
  });

  test("@contentRole none removes container semantics", async function (assert) {
    await render(
      <template>
        <DMenu @contentRole="none" @inline={{true}} @label="label" />
      </template>
    );

    await open();

    assert
      .dom(".fk-d-menu")
      .hasAttribute("role", "none", "the requested role is rendered");
    assert
      .dom(".fk-d-menu")
      .doesNotHaveAttribute(
        "aria-labelledby",
        "the presentational container has no accessible name"
      );
    assert
      .dom(".fk-d-menu")
      .doesNotHaveAttribute(
        "aria-expanded",
        "the presentational container has no ARIA state"
      );
  });

  test("service-created menus use @contentRole", async function (assert) {
    await render(
      <template>
        <div class="menu-trigger"></div>
        <DMenus />
      </template>
    );

    await getOwner(this).lookup("service:menu").show(find(".menu-trigger"), {
      content: "content",
      contentRole: "none",
    });
    await settled();

    assert
      .dom(".fk-d-menu")
      .hasAttribute("role", "none", "the service option reaches the menu body");
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

  test("trigger disabled argument reflects the disabled state", async function (assert) {
    this.disabled = false;

    await render(
      <template>
        <DMenu @disabled={{this.disabled}} @inline={{true}}>
          <:trigger as |args|>
            <span class="disabled-flag">{{if args.disabled "off" "on"}}</span>
          </:trigger>
          <:content>content</:content>
        </DMenu>
      </template>
    );

    assert.dom(".disabled-flag").hasText("on", "disabled is false by default");

    this.set("disabled", true);
    await rerender();
    assert
      .dom(".disabled-flag")
      .hasText(
        "off",
        "a custom trigger sees the veto it cannot read from @disabled"
      );
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

  test("closing hands focus back to the trigger when the menu holds it", async function (assert) {
    await render(
      <template>
        <span class="test">test</span><DMenu
          @inline={{true}}
          @label="label"
          @autofocus={{true}}
        >
          <:content>
            <DButton class="my-button" />
          </:content>
        </DMenu>
      </template>
    );

    await open();
    assert.dom(document.activeElement).hasClass("my-button");

    await triggerEvent(".test", "pointerdown");

    assert
      .dom(document.activeElement)
      .hasClass(
        "fk-d-menu__trigger",
        "a click outside closes the menu and returns focus to the trigger"
      );

    await open();
    await close();

    assert
      .dom(document.activeElement)
      .hasClass(
        "fk-d-menu__trigger",
        "toggling the menu shut from its trigger also returns focus"
      );
  });

  test("closing leaves focus alone when something else has taken it", async function (assert) {
    await render(
      <template>
        <DButton class="outside-button" /><DMenu
          @inline={{true}}
          @label="label"
          @autofocus={{true}}
        >
          <:content>
            <DButton class="my-button" />
          </:content>
        </DMenu>
      </template>
    );

    await open();
    await focus(".outside-button");
    await triggerEvent(".outside-button", "pointerdown");

    assert
      .dom(document.activeElement)
      .hasClass(
        "outside-button",
        "focus stays where the user put it rather than snapping to the trigger"
      );
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

  test("focusTrigger=false still rescues focus the menu was holding", async function (assert) {
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

    assert.dom(".fk-d-menu__trigger").isFocused();
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

    this.set("disabled", true);
    await settled();
    assert
      .dom(".fk-d-menu")
      .doesNotExist("setting disabled closes an open menu");

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

  test("disabling an open menu returns focus to a trigger that stays focusable", async function (assert) {
    this.disabled = false;

    await render(
      <template>
        <DMenu
          @disabled={{this.disabled}}
          @inline={{true}}
          @triggerComponent={{dElement "div"}}
          tabindex="0"
        >
          <:content><input class="menu-input" /></:content>
        </DMenu>
      </template>
    );

    await click(".fk-d-menu__trigger");
    await focus(".menu-input");
    assert.dom(".menu-input").isFocused("focus moved into the open menu");

    this.set("disabled", true);
    await settled();

    assert.dom(".fk-d-menu").doesNotExist("becoming disabled closed the menu");
    assert
      .dom(".fk-d-menu__trigger")
      .isFocused(
        "the close hands focus back, so a caller that keeps its trigger focusable does not lose it"
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

  test("@hoverGracePeriod keeps the menu open while the pointer crosses to the content", async function (assert) {
    await render(
      <template>
        <DMenu
          @inline={{true}}
          @label="label"
          @triggers={{array "hover"}}
          @untriggers={{array "hover"}}
          @hoverGracePeriod={{150}}
          @content="content"
        />
      </template>
    );

    await triggerEvent(".fk-d-menu__trigger", "pointermove");
    assert.dom(".fk-d-menu").exists();

    const trigger = document.querySelector(".fk-d-menu__trigger");
    const content = document.querySelector(".fk-d-menu");
    trigger.dispatchEvent(new PointerEvent("pointerleave"));
    content.dispatchEvent(new PointerEvent("pointerenter"));
    await settled();

    assert.dom(".fk-d-menu").exists();
  });

  test("@hoverGracePeriod closes the menu after the grace period when the pointer leaves entirely", async function (assert) {
    await render(
      <template>
        <DMenu
          @inline={{true}}
          @label="label"
          @triggers={{array "hover"}}
          @untriggers={{array "hover"}}
          @hoverGracePeriod={{150}}
          @content="content"
        />
      </template>
    );

    await triggerEvent(".fk-d-menu__trigger", "pointermove");
    await triggerEvent(".fk-d-menu__trigger", "pointerleave");

    assert.dom(".fk-d-menu").doesNotExist();
  });

  test("default hoverGracePeriod (0) does not install hover-close on interactive menus", async function (assert) {
    await render(
      <template>
        <DMenu
          @inline={{true}}
          @label="label"
          @triggers={{array "hover"}}
          @untriggers={{array "hover"}}
          @content="content"
        />
      </template>
    );

    await triggerEvent(".fk-d-menu__trigger", "pointermove");
    await triggerEvent(".fk-d-menu__trigger", "pointerleave");

    assert
      .dom(".fk-d-menu")
      .exists("interactive menu stays open without grace period");
  });
});
