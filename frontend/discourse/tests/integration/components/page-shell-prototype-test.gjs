import {
  click,
  find,
  render,
  triggerEvent,
  waitUntil,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import PageShellPrototype from "discourse/components/page-shell-prototype";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

async function choose(name, value) {
  const selector = `.shell-prototype-controls select[name="${name}"]`;
  find(selector).value = value;
  await triggerEvent(selector, "change");
}

module("Integration | Component | page shell prototype", function (hooks) {
  setupRenderingTest(hooks, { stubRouter: true });

  hooks.beforeEach(function () {
    this.siteSettings.enable_page_shell_prototype = true;
    this.siteSettings.enable_main_outlet_grid_layout_change = true;
    this.shell = this.owner.lookup("service:page-shell-prototype");
  });

  test("requires the new composer grid and preserves the legacy wrapper otherwise", async function (assert) {
    this.siteSettings.enable_main_outlet_grid_layout_change = false;

    await render(
      <template>
        <PageShellPrototype>
          <:header><header data-test-header>Header</header></:header>
          <:body><div id="main-outlet">Route</div></:body>
          <:footer><footer data-test-footer>Footer</footer></:footer>
        </PageShellPrototype>
      </template>
    );

    assert.dom(".page-shell-prototype").doesNotExist();
    assert.dom(".shell-prototype-controls").doesNotExist();
    assert.dom("#main-outlet-wrapper").hasAttribute("role", "main");
    assert.dom("[data-test-header]").exists({ count: 1 });
    assert.dom("[data-test-footer]").exists({ count: 1 });
    assert.dom("#main-outlet-wrapper [data-test-footer]").doesNotExist();
  });

  test("the setting is opt in even with the new composer grid", async function (assert) {
    this.siteSettings.enable_page_shell_prototype = false;
    await render(
      <template>
        <PageShellPrototype><:body>Route</:body></PageShellPrototype>
      </template>
    );
    assert.dom(".page-shell-prototype").doesNotExist();
    assert.dom("#main-outlet-wrapper").hasAttribute("role", "main");
  });

  test("panel controls preserve a single body, footer and composer grid host", async function (assert) {
    await render(
      <template>
        <PageShellPrototype @showFooter={{true}} @sidebarEnabled={{true}}>
          <:header><header data-test-header>Header</header></:header>
          <:body>
            <main id="main-outlet">Route</main>
            <div id="reply-control">Composer</div>
          </:body>
          <:footer><footer data-test-footer>Footer</footer></:footer>
        </PageShellPrototype>
      </template>
    );

    await click(".shell-prototype-controls summary");
    await choose("width", "full");
    await choose("left", "rail");
    await choose("right", "rail");
    await choose("footer", "row");

    assert.dom(".page-shell-prototype").hasAttribute("data-width", "full");
    assert.dom(".page-shell-prototype").hasAttribute("data-left", "rail");
    assert.dom(".page-shell-prototype").hasAttribute("data-right", "rail");
    assert.dom(".page-shell-prototype").hasAttribute("data-footer", "row");
    assert.dom("#main-outlet-wrapper > #reply-control").exists({ count: 1 });
    assert.dom("#main-outlet-wrapper").doesNotHaveAttribute("role");
    assert.dom("[data-test-header]").exists({ count: 1 });
    assert.dom("#main-outlet-wrapper [data-test-footer]").exists({ count: 1 });

    await click(".page-shell-prototype__right button");
    assert.dom(".page-shell-prototype").hasAttribute("data-right", "open");
    assert.dom('select[name="right"]').hasValue("open");
  });

  test("temporary right panel availability does not overwrite preferences", async function (assert) {
    this.shell.right = "rail";
    const router = this.owner.lookup("service:router");
    router.currentRouteName = "user.preferences.account";

    await render(
      <template>
        <PageShellPrototype><:body><main
              id="main-outlet"
            >Preferences</main></:body></PageShellPrototype>
      </template>
    );

    assert.dom(".page-shell-prototype").hasAttribute("data-right", "hidden");
    assert.dom(".page-shell-prototype__right-slot").doesNotExist();
    assert.dom('select[name="right"]').isDisabled();
    assert.strictEqual(this.shell.right, "rail");

    router.currentRouteName = "discovery.latest";
    await waitUntil(() => find(".page-shell-prototype__right-slot"));
    assert.dom(".page-shell-prototype").hasAttribute("data-right", "rail");
  });

  test("composer alignment follows content geometry after a panel width change", async function (assert) {
    await render(
      <template>
        <PageShellPrototype @sidebarEnabled={{true}}>
          <:body><main id="main-outlet">Route</main></:body>
        </PageShellPrototype>
      </template>
    );

    const shell = find(".page-shell-prototype");
    await waitUntil(() =>
      shell.style.getPropertyValue("--shell-prototype-content-width")
    );
    await click(".shell-prototype-controls summary");
    find('input[name="leftWidth"]').value = "400";
    await triggerEvent('input[name="leftWidth"]', "input");
    await waitUntil(() => {
      const actual = find("#main-outlet").getBoundingClientRect();
      return (
        Math.abs(
          parseFloat(
            shell.style.getPropertyValue(
              "--shell-prototype-content-inline-start"
            )
          ) - actual.left
        ) < 0.5 &&
        Math.abs(
          parseFloat(
            shell.style.getPropertyValue("--shell-prototype-content-width")
          ) - actual.width
        ) < 0.5
      );
    });
    assert.strictEqual(this.shell.leftWidth, 400);
  });

  test("header search stays centered with a rail and overflowing header actions", async function (assert) {
    this.shell.left = "rail";
    this.shell.right = "hidden";

    await render(
      <template>
        <div style="width: 1440px;">
          <PageShellPrototype @sidebarEnabled={{true}}>
            <:header>
              <div class="d-header-wrap">
                <header class="d-header">
                  <div class="wrap">
                    <div class="contents">
                      <div class="page-shell-prototype__header-start">Menu</div>
                      <div class="page-shell-prototype__header-main">
                        <div class="floating-search-input-wrapper">
                          <div class="floating-search-input">Search</div>
                        </div>
                      </div>
                      <nav class="panel"><button type="button">Long header
                          action</button></nav>
                    </div>
                  </div>
                </header>
              </div>
            </:header>
            <:body><main id="main-outlet">Route</main></:body>
          </PageShellPrototype>
        </div>
      </template>
    );

    const element = find(".page-shell-prototype");
    await waitUntil(() =>
      element.style.getPropertyValue("--shell-prototype-header-end-width")
    );
    const mainBox = find("#main-outlet").getBoundingClientRect();
    const searchBox = find(".floating-search-input").getBoundingClientRect();
    assert.true(
      Math.abs(
        mainBox.left + mainBox.width / 2 - searchBox.left - searchBox.width / 2
      ) < 1,
      "header chrome reserves equal space around the centered search"
    );
  });

  test("RTL composer follows the content's logical start edge", async function (assert) {
    await render(
      <template>
        <div dir="rtl" style="width: 1440px;">
          <PageShellPrototype @sidebarEnabled={{true}}>
            <:body>
              <main id="main-outlet">Route</main>
              <div id="reply-control" style="transition: none;">Composer</div>
            </:body>
          </PageShellPrototype>
        </div>
      </template>
    );

    const shellElement = find(".page-shell-prototype");
    await waitUntil(() =>
      shellElement.style.getPropertyValue(
        "--shell-prototype-content-inline-start"
      )
    );
    const contentBox = find("#main-outlet").getBoundingClientRect();
    const expectedStart =
      document.documentElement.clientWidth - contentBox.right;
    // The QUnit fixture is transformed and establishes a fixed containing
    // block. Check the viewport-relative value and its CSS consumption here;
    // actual fixed positioning is covered in the untransformed browser page.
    const composerStyle = getComputedStyle(find("#reply-control"));
    assert.true(
      Math.abs(parseFloat(composerStyle.insetInlineStart) - expectedStart) < 1
    );
    assert.true(
      Math.abs(parseFloat(composerStyle.width) - contentBox.width) < 1
    );
  });
});
