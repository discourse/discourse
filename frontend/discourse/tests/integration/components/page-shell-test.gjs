import {
  click,
  find,
  render,
  triggerEvent,
  triggerKeyEvent,
  waitUntil,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import PageShell from "discourse/components/page-shell";
import SidebarWrapper from "discourse/components/sidebar-wrapper";
import {
  readShellGeometry,
  shellTracks,
} from "discourse/lib/page-shell-geometry";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

async function choose(name, value) {
  const selector = `.page-shell-controls select[name="${name}"]`;
  find(selector).value = value;
  await triggerEvent(selector, "change");
}

module("Integration | Component | page shell", function (hooks) {
  setupRenderingTest(hooks, { stubRouter: true });

  hooks.beforeEach(function () {
    this.siteSettings.enable_page_shell_prototype = true;
    this.siteSettings.enable_main_outlet_grid_layout_change = true;
    this.shell = this.owner.lookup("service:page-shell");
  });

  test("requires the new composer grid and preserves the legacy wrapper otherwise", async function (assert) {
    this.siteSettings.enable_main_outlet_grid_layout_change = false;

    await render(
      <template>
        <PageShell>
          <:header><header data-test-header>Header</header></:header>
          <:navigation><SidebarWrapper @showSidebar={{false}} /></:navigation>
          <:main>Route</:main>
          <:footer><footer data-test-footer>Footer</footer></:footer>
        </PageShell>
      </template>
    );

    assert.dom(".page-shell").doesNotExist();
    assert.dom(".page-shell-controls").doesNotExist();
    assert.dom("#main-outlet-wrapper").hasAttribute("role", "main");
    assert.dom("[data-test-header]").exists({ count: 1 });
    assert.dom("[data-test-footer]").exists({ count: 1 });
    assert.dom("#main-outlet-wrapper [data-test-footer]").doesNotExist();
  });

  test("the setting is opt in even with the new composer grid", async function (assert) {
    this.siteSettings.enable_page_shell_prototype = false;
    await render(
      <template>
        <PageShell><:main>Route</:main></PageShell>
      </template>
    );
    assert.dom(".page-shell").doesNotExist();
    assert.dom("#main-outlet-wrapper").hasAttribute("role", "main");
  });

  test("shell regions are direct children of the composer grid host", async function (assert) {
    await render(
      <template>
        <PageShell @showFooter={{true}} @sidebarEnabled={{true}}>
          <:header><header data-test-header>Header</header></:header>
          <:navigation><SidebarWrapper @showSidebar={{false}} /></:navigation>
          <:main>
            Route
          </:main>
          <:composer><div id="reply-control">Composer</div></:composer>
          <:footer><footer data-test-footer>Footer</footer></:footer>
        </PageShell>
      </template>
    );

    await click(".page-shell-controls summary");
    await choose("width", "full");
    await choose("navigation", "rail");
    await choose("footer", "row");

    assert.dom(".page-shell").hasAttribute("data-width", "full");
    assert.dom(".page-shell").hasAttribute("data-navigation", "rail");
    assert.dom(".page-shell").hasAttribute("data-context", "open");
    assert.dom(".page-shell").hasAttribute("data-footer", "row");
    assert.dom("#main-outlet-wrapper > #reply-control").exists({ count: 1 });
    assert.dom("#main-outlet-wrapper").doesNotHaveAttribute("role");
    assert.dom("[data-test-header]").exists({ count: 1 });
    assert.dom("#main-outlet-wrapper > [data-test-header]").exists();
    assert.dom("#main-outlet-wrapper > .page-shell__navigation").exists();
    assert.dom("#main-outlet-wrapper > main.page-shell__main").exists();
    assert.dom("#main-outlet-wrapper > footer.page-shell__footer").exists();
    assert.dom("#main-outlet-wrapper > aside.page-shell__context").exists();
    assert.dom(".page-shell #main-outlet-wrapper").doesNotExist();
    assert.dom(".page-shell > #main-outlet.page-shell__main").exists();
    assert.dom("#main-outlet #main-outlet").doesNotExist();
    assert.dom(".page-shell__navigation .sidebar-wrapper").doesNotExist();
    assert.dom("#main-outlet-wrapper [data-test-footer]").exists({ count: 1 });
  });

  test("temporary context panel availability does not overwrite preferences", async function (assert) {
    this.shell.context = "open";
    const router = this.owner.lookup("service:router");
    router.currentRouteName = "user.preferences.account";

    await render(
      <template>
        <PageShell><:main>Preferences</:main></PageShell>
      </template>
    );

    assert.dom(".page-shell").hasAttribute("data-context", "hidden");
    assert.dom(".page-shell__context").doesNotExist();
    assert.dom('select[name="context"]').isDisabled();
    assert.strictEqual(this.shell.context, "open");

    router.currentRouteName = "discovery.latest";
    await waitUntil(() => find(".page-shell__context"));
    assert.dom(".page-shell").hasAttribute("data-context", "open");
  });

  test("panel caps preserve the main minimum when either panel grows", async function (assert) {
    await render(
      <template>
        <div class="shell-panel-caps-test" style="width: 2000px;">
          <PageShell @sidebarEnabled={{true}}><:main>Route</:main></PageShell>
        </div>
      </template>
    );
    await choose("width", "full");
    await waitUntil(() => this.shell.contextMaxWidth === 1000);
    this.shell.change({ target: { name: "navigationWidth", value: "9999" } });
    this.shell.change({ target: { name: "contextWidth", value: "9999" } });
    await waitUntil(
      () => getComputedStyle(find("#main-outlet")).width === "600px"
    );
    assert.strictEqual(this.shell.navigationWidth, 400);
    assert.strictEqual(this.shell.contextWidth, 1000);
    assert.dom('input[name="navigationWidth"]').hasAttribute("max", "400");
    assert.dom('input[name="contextWidth"]').hasAttribute("max", "1000");

    const wrapper = find(".shell-panel-caps-test");
    wrapper.style.width = "1100px";
    await waitUntil(() => this.shell.contextMaxWidth === 252);
    assert.strictEqual(getComputedStyle(find("#main-outlet")).width, "448px");

    wrapper.style.width = "768px";
    assert.strictEqual(
      getComputedStyle(find("#main-outlet")).width,
      "448px",
      "Navigation cannot squeeze Main while Context is collapsing"
    );
    await waitUntil(() =>
      find(".page-shell").hasAttribute("data-constrained-context")
    );
    assert.strictEqual(getComputedStyle(find("#main-outlet")).width, "448px");
  });

  test("context expands to the main minimum and adapts without losing its preferred width", async function (assert) {
    await render(
      <template>
        <div class="shell-resize-test" style="width: 1440px;">
          <PageShell @sidebarEnabled={{true}}><:main>Route</:main></PageShell>
        </div>
      </template>
    );

    await choose("width", "full");
    const input = find('input[name="contextWidth"]');
    await waitUntil(() => Number(input.max) === 732);
    input.value = input.max;
    await triggerEvent(input, "input");
    assert.strictEqual(
      this.shell.contextWidth,
      732,
      "Context expands within the space available to Main"
    );
    assert.strictEqual(getComputedStyle(find("#main-outlet")).width, "448px");
    assert.dom(".page-shell").doesNotHaveAttribute("data-constrained-context");

    find(".shell-resize-test").style.width = "1100px";
    await waitUntil(() => Number(input.max) === 392);
    assert.strictEqual(getComputedStyle(find("#main-outlet")).width, "448px");
    assert.strictEqual(
      this.shell.contextWidth,
      732,
      "shrinking keeps the preferred width"
    );
    assert.strictEqual(this.shell.effectiveContextWidth, 392);
    assert.dom(".page-shell").doesNotHaveAttribute("data-constrained-context");

    find(".shell-resize-test").style.width = "1440px";
    await waitUntil(() => Number(input.max) === 732);
    assert.strictEqual(this.shell.effectiveContextWidth, 732);

    find(".page-shell").style.setProperty(
      "--_page-shell-composer-track-width",
      "300px"
    );
    await waitUntil(() => Number(input.max) === 432);
    assert.strictEqual(getComputedStyle(find("#main-outlet")).width, "448px");
  });

  test("main padding and composer clearance belong to the content frame", async function (assert) {
    await render(
      <template>
        <div
          style="--main-outlet-padding-top: 32px; --main-outlet-padding-bottom: 20px; --composer-height: 240px;"
        >
          <PageShell><:main>Route</:main></PageShell>
        </div>
      </template>
    );

    const region = find("#main-outlet");
    const content = find(".page-shell__main-content");
    assert.strictEqual(getComputedStyle(region).padding, "0px");
    assert.strictEqual(getComputedStyle(content).paddingTop, "32px");
    assert.strictEqual(getComputedStyle(content).paddingBottom, "20px");

    const html = document.documentElement;
    const composerWasOpen = html.classList.contains("composer-open");
    html.classList.add("composer-open");
    try {
      await waitUntil(
        () => getComputedStyle(content).paddingBottom === "240px"
      );
      assert.strictEqual(getComputedStyle(region).padding, "0px");
      assert.strictEqual(getComputedStyle(content).paddingBottom, "240px");
    } finally {
      html.classList.toggle("composer-open", composerWasOpen);
    }
  });

  test("composer alignment follows content geometry after a panel width change", async function (assert) {
    await render(
      <template>
        <PageShell @sidebarEnabled={{true}}>
          <:main>Route</:main>
        </PageShell>
      </template>
    );

    const shell = find(".page-shell");
    await waitUntil(() =>
      shell.style.getPropertyValue("--_page-shell-content-width")
    );
    await click(".page-shell-controls summary");
    find('input[name="navigationWidth"]').value = "400";
    await triggerEvent('input[name="navigationWidth"]', "input");
    await waitUntil(() => {
      const actual = find(".page-shell__main-content").getBoundingClientRect();
      return (
        Math.abs(
          parseFloat(
            shell.style.getPropertyValue("--_page-shell-content-inline-start")
          ) - actual.left
        ) < 0.5 &&
        Math.abs(
          parseFloat(
            shell.style.getPropertyValue("--_page-shell-content-width")
          ) - actual.width
        ) < 0.5
      );
    });
    assert.strictEqual(this.shell.navigationWidth, 400);
  });

  test("header search stays over Main with a rail and header actions", async function (assert) {
    this.shell.navigation = "rail";
    this.shell.context = "hidden";

    await render(
      <template>
        <div style="width: 1440px;">
          <PageShell @sidebarEnabled={{true}}>
            <:header>
              <div class="d-header-wrap">
                <header class="d-header">
                  <div class="wrap">
                    <div class="contents">
                      <div class="page-shell__header-start">Menu</div>
                      <div class="page-shell__header-main">
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
            <:main>Route</:main>
          </PageShell>
        </div>
      </template>
    );

    const element = find(".page-shell");
    await waitUntil(() =>
      element.style.getPropertyValue("--_page-shell-header-end-width")
    );
    const searchFitsMainHeader = () => {
      const mainBox = find(".page-shell__main").getBoundingClientRect();
      const searchBox = find(".floating-search-input").getBoundingClientRect();
      const actionsBox = find(".d-header .panel").getBoundingClientRect();
      return (
        searchBox.left >= mainBox.left && searchBox.right <= actionsBox.left
      );
    };
    assert.true(
      searchFitsMainHeader(),
      "search stays between Main’s start and the actions"
    );

    const measuredWidths = [];
    const observer = new MutationObserver(() => {
      measuredWidths.push(
        element.style.getPropertyValue("--_page-shell-header-start-width")
      );
    });
    observer.observe(element, { attributes: true, attributeFilter: ["style"] });
    await choose("context", "open");
    const contextWidth = find('input[name="contextWidth"]');
    contextWidth.value = "480";
    await triggerEvent(contextWidth, "input");
    observer.disconnect();
    assert.true(measuredWidths.length > 0);
    assert.true(
      measuredWidths.every(Boolean),
      "panel resizing preserves measured header widths between frames"
    );
    assert.true(
      searchFitsMainHeader(),
      "search stays over Main after a resize"
    );
  });

  test("wide logos are capped at the navigation maximum", async function (assert) {
    const wideLogo = `data:image/svg+xml,${encodeURIComponent(
      '<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="100"></svg>'
    )}`;

    await render(
      <template>
        <div style="width: 1920px;">
          <PageShell @sidebarEnabled={{true}}>
            <:header>
              <div class="d-header-wrap">
                <header class="d-header">
                  <div class="wrap">
                    <div class="contents">
                      <div class="page-shell__header-start">
                        <div class="home-logo-wrapper-outlet">
                          <div class="title">
                            <a href="/"><img
                                alt=""
                                id="site-logo"
                                src={{wideLogo}}
                              /></a>
                          </div>
                        </div>
                      </div>
                      <div class="page-shell__header-main"></div>
                      <nav class="panel">Actions</nav>
                    </div>
                  </div>
                </header>
              </div>
            </:header>
            <:main>Route</:main>
          </PageShell>
        </div>
      </template>
    );

    const logo = find("#site-logo");
    await waitUntil(() => logo.complete && logo.naturalWidth > 0);
    const start = find(".page-shell__header-start").getBoundingClientRect();
    const logoBox = logo.getBoundingClientRect();
    assert.true(start.width <= 400, `header start is ${start.width}px wide`);
    assert.true(
      logoBox.right <= start.right + 0.5,
      "the logo scales down inside the capped cell"
    );
  });

  test("the header switches to the compact logo without oscillating", async function (assert) {
    this.shell.width = "full";
    this.shell.navigation = "hidden";
    this.shell.context = "hidden";

    await render(
      <template>
        <div class="shell-logo-test" style="width: 1440px;">
          <PageShell @sidebarEnabled={{true}}>
            <:header>
              <div class="d-header-wrap">
                <header class="d-header">
                  <div class="wrap">
                    <div class="contents">
                      <div class="page-shell__header-start">
                        {{#if this.shell.compactLogo}}
                          <div style="width: 40px;">Small</div>
                        {{else}}
                          <div style="width: 380px;">Full logo</div>
                        {{/if}}
                      </div>
                      <div class="page-shell__header-main"></div>
                      <nav class="panel" style="width: 300px;">Actions</nav>
                    </div>
                  </div>
                </header>
              </div>
            </:header>
            <:main>Route</:main>
          </PageShell>
        </div>
      </template>
    );

    const shellElement = find(".page-shell");
    await waitUntil(() =>
      shellElement.style.getPropertyValue("--_page-shell-header-start-width")
    );
    assert.false(this.shell.compactLogo, "the full logo fits at 1440px");

    const wrapper = find(".shell-logo-test");
    wrapper.style.width = "850px";
    await waitUntil(() => this.shell.compactLogo);
    await waitUntil(
      () =>
        shellElement.style.getPropertyValue(
          "--_page-shell-header-start-width"
        ) !== "380px"
    );
    await new Promise((resolve) => requestAnimationFrame(resolve));
    await new Promise((resolve) => requestAnimationFrame(resolve));
    assert.true(
      this.shell.compactLogo,
      "the narrower compact logo does not switch the full logo back on"
    );

    wrapper.style.width = "1440px";
    await waitUntil(() => !this.shell.compactLogo);
    assert.dom(".page-shell__header-start").hasText("Full logo");
  });

  test("the geometry model matches the rendered tracks", async function (assert) {
    await render(
      <template>
        <div style="width: 2000px;">
          <PageShell @sidebarEnabled={{true}}><:main>Route</:main></PageShell>
        </div>
      </template>
    );
    const shellElement = find(".page-shell");
    const frame = () =>
      new Promise((resolve) =>
        requestAnimationFrame(() => requestAnimationFrame(resolve))
      );

    for (const state of [
      { width: "centered", resize: "grow" },
      { width: "centered", resize: "content" },
      { width: "centered", resize: "content", navigationWidth: 400 },
      { width: "centered", resize: "grow", contextWidth: 1000 },
      { width: "centered", resize: "content", contextWidth: 1000 },
      { width: "centered", resize: "content", navigation: "rail" },
      { width: "full", resize: "content", context: "hidden" },
    ]) {
      Object.assign(this.shell, {
        navigation: "open",
        context: "open",
        navigationWidth: 260,
        contextWidth: 300,
        ...state,
      });
      await frame();
      const predicted = Object.values(
        shellTracks(readShellGeometry(shellElement, this.shell))
      );
      const rendered = getComputedStyle(shellElement)
        .gridTemplateColumns.split(" ")
        .map(parseFloat);
      assert.true(
        predicted.every(
          (track, index) => Math.abs(track - rendered[index]) < 1
        ),
        `${JSON.stringify(state)}: predicted ${predicted.map(Math.round)}, rendered ${rendered.map(Math.round)}`
      );
    }
  });

  test("keyboard resizing steps the width directly and saves on release", async function (assert) {
    await render(
      <template>
        <div style="width: 2000px;">
          <PageShell @sidebarEnabled={{true}}><:main>Route</:main></PageShell>
        </div>
      </template>
    );
    await waitUntil(() => this.shell.contextMaxWidth === 1000);

    const separator = ".page-shell__separator--context";
    assert.dom(separator).hasAttribute("role", "separator");
    assert.dom(separator).hasAttribute("aria-valuenow", "300");

    // Context sits at the inline end, so ArrowLeft grows it in LTR.
    await triggerKeyEvent(separator, "keydown", "ArrowRight");
    await triggerKeyEvent(separator, "keydown", "ArrowRight");
    assert.strictEqual(this.shell.contextWidth, 332);
    assert.dom(separator).hasAttribute("aria-valuenow", "332");

    await triggerKeyEvent(separator, "keyup", "ArrowRight");
    const store = this.owner.lookup("service:key-value-store");
    assert.strictEqual(store.getObject("page-shell-panels").context.width, 332);

    await triggerKeyEvent(separator, "keydown", "Home");
    await triggerKeyEvent(separator, "keyup", "Home");
    assert.strictEqual(this.shell.contextWidth, 200);
  });

  test("only open panels get a separator", async function (assert) {
    this.shell.context = "hidden";
    await render(
      <template>
        <PageShell @sidebarEnabled={{true}}><:main>Route</:main></PageShell>
      </template>
    );
    assert.dom(".page-shell__separator--context").doesNotExist();
  });

  test("RTL composer follows the content's logical start edge", async function (assert) {
    await render(
      <template>
        <div dir="rtl" style="width: 1440px;">
          <PageShell @sidebarEnabled={{true}}>
            <:main>
              Route
            </:main>
            <:composer><div
                id="reply-control"
                style="transition: none;"
              >Composer</div></:composer>
          </PageShell>
        </div>
      </template>
    );

    const shellElement = find(".page-shell");
    await waitUntil(() =>
      shellElement.style.getPropertyValue("--_page-shell-content-inline-start")
    );
    const contentBox = find(
      ".page-shell__main-content"
    ).getBoundingClientRect();
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
