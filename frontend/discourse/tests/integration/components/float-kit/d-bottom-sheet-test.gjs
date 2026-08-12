import { tracked } from "@glimmer/tracking";
import {
  click,
  find,
  focus,
  render,
  settled,
  waitFor,
  waitUntil,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import DBottomSheet from "discourse/float-kit/components/d-bottom-sheet";
import DCard from "discourse/float-kit/components/d-card";
import DStack from "discourse/float-kit/components/d-stack";
import { capabilities } from "discourse/services/capabilities";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

const OPEN_VIEW_SELECTOR =
  "[data-d-sheet~='view'][data-d-sheet~='staging-none']:not([data-d-sheet~='closed'])";

module("Integration | Component | FloatKit | d-bottom-sheet", function (hooks) {
  setupRenderingTest(hooks);
  hooks.afterEach(() => sinon.restore());

  test("opens when trigger is clicked", async function (assert) {
    await render(
      <template>
        <DBottomSheet as |bs|>
          <bs.Trigger>Open</bs.Trigger>
          <bs.Content as |content|>
            <p>Content</p>
            <content.Trigger @action="dismiss">Close</content.Trigger>
          </bs.Content>
        </DBottomSheet>
      </template>
    );

    assert.dom("[data-d-sheet~='view']").doesNotExist();

    await click(".btn");
    await waitFor("[data-d-sheet~='view']");
    await new Promise((resolve) => setTimeout(resolve, 750));

    assert
      .dom("[data-d-sheet~='view']")
      .isVisible("the settled bottom sheet remains visible");
    assert.notStrictEqual(
      getComputedStyle(find("[data-d-sheet~='view']")).opacity,
      "0",
      "the settled bottom sheet remains opaque"
    );
  });

  test("opens by default with @defaultPresented", async function (assert) {
    await render(
      <template>
        <DBottomSheet @defaultPresented={{true}} as |bs|>
          <bs.Content as |content|>
            <p>Content</p>
            <content.Trigger @action="dismiss">Close</content.Trigger>
          </bs.Content>
        </DBottomSheet>
      </template>
    );

    await waitFor("[data-d-sheet~='view']");

    assert
      .dom("[data-d-sheet~='view']")
      .hasAttribute("role", "dialog", "the bottom-sheet preset is a dialog");
  });

  test("closes when dismiss trigger is clicked", async function (assert) {
    await render(
      <template>
        <DBottomSheet as |bs|>
          <bs.Trigger>Open</bs.Trigger>
          <bs.Content as |content|>
            <p>Content</p>
            <content.Trigger
              @action="dismiss"
              class="dismiss-btn"
            >Close</content.Trigger>
          </bs.Content>
        </DBottomSheet>
      </template>
    );

    await click(".btn");
    await waitFor(OPEN_VIEW_SELECTOR);
    await click(".dismiss-btn");
    await waitFor("[data-d-sheet~='view'][data-d-sheet~='closed']", {
      timeout: 3000,
    });

    const closedRect = find("[data-d-sheet~='view']").getBoundingClientRect();
    assert.true(
      closedRect.width <= 1,
      "the pending bottom sheet width is collapsed"
    );
    assert.true(
      closedRect.height <= 1,
      "the pending bottom sheet height is collapsed"
    );

    await waitUntil(() => !find("[data-d-sheet~='view']"), { timeout: 5000 });

    assert.dom("[data-d-sheet~='view']").doesNotExist();
  });

  test("opens and closes with other sheet roots mounted", async function (assert) {
    await render(
      <template>
        <DBottomSheet as |bs|>
          <bs.Trigger class="open-bottom-sheet">Open Bottom Sheet</bs.Trigger>
          <bs.Content as |content|>
            <p>Bottom sheet content here</p>
            <content.Trigger
              @action="dismiss"
              class="close-bottom-sheet"
            >Close</content.Trigger>
          </bs.Content>
        </DBottomSheet>

        <DCard as |card|>
          <card.Trigger class="open-card">Open Card</card.Trigger>
          <card.Content as |content|>
            <p>Card content here</p>
            <content.Trigger @action="dismiss">Close</content.Trigger>
          </card.Content>
        </DCard>

        <DStack as |stack|>
          <stack.Trigger class="open-stack">Open Stack</stack.Trigger>
          <stack.Content as |content|>
            <p>First level content</p>
            <content.Trigger @action="dismiss">Close</content.Trigger>
          </stack.Content>
        </DStack>
      </template>
    );

    await click(".open-bottom-sheet");
    await waitFor(OPEN_VIEW_SELECTOR);
    await click(".close-bottom-sheet");
    await waitFor("[data-d-sheet~='view'][data-d-sheet~='closed']", {
      timeout: 3000,
    });

    assert
      .dom("[data-d-sheet~='view'][data-d-sheet~='closed']")
      .exists("the Styleguide-shaped sheet closes without reopening");
    assert
      .dom("[data-d-sheet~='view'][data-d-sheet~='closed']")
      .doesNotHaveAttribute(
        "aria-modal",
        "the pending View is no longer exposed as the active modal"
      );
    assert.dom(".open-card").exists("the adjacent card root remains mounted");
    assert.dom(".open-stack").exists("the adjacent stack root remains mounted");
    assert.strictEqual(
      find(".open-card").closest("[inert]"),
      null,
      "the page is interactive as soon as the sheet closes"
    );
    assert.notStrictEqual(
      document.body.style.overflow,
      "hidden",
      "the page scroll lock is released as soon as the sheet closes"
    );

    await click(".open-card");
    await waitFor(".d-card:not([data-d-sheet~='closed'])", { timeout: 3000 });

    assert
      .dom(".d-card:not([data-d-sheet~='closed'])")
      .exists("another sheet can be opened during the closed pending window");
  });

  test("renders backdrop when open", async function (assert) {
    await render(
      <template>
        <DBottomSheet as |bs|>
          <bs.Trigger>Open</bs.Trigger>
          <bs.Content>
            <p>Content</p>
          </bs.Content>
        </DBottomSheet>
      </template>
    );

    await click(".btn");
    await waitFor("[data-d-sheet~='view']");

    assert.dom("[data-d-sheet~='view']").exists();
    assert.dom("[data-d-sheet~='backdrop']").exists();
  });

  test("uses automatic theme-color dimming", async function (assert) {
    const themeColorManager = this.owner.lookup("service:theme-color-manager");
    const captureUnderlyingColor = sinon
      .stub(themeColorManager, "getAndStoreUnderlyingThemeColorAsRGBArray")
      .returns(false);

    sinon.stub(capabilities, "isWebKit").value(true);
    sinon
      .stub(capabilities, "isStandaloneWithBlackTranslucent")
      .get(() => false);

    await render(
      <template>
        <DBottomSheet @defaultPresented={{true}} as |bs|>
          <bs.Content>Content</bs.Content>
        </DBottomSheet>
      </template>
    );

    await waitUntil(() => captureUnderlyingColor.called, { timeout: 3000 });

    assert.true(
      captureUnderlyingColor.calledOnce,
      "the preset enables the WebKit theme-color dimming overlay"
    );
  });

  test("controlled mode with @presented and @onPresentedChange", async function (assert) {
    const state = new (class {
      @tracked presented = false;
    })();

    const onPresentedChange = (value) => (state.presented = value);

    await render(
      <template>
        <DBottomSheet
          @presented={{state.presented}}
          @onPresentedChange={{onPresentedChange}}
          as |bs|
        >
          <bs.Trigger>Open</bs.Trigger>
          <bs.Content as |content|>
            <p>Content</p>
            <content.Trigger
              @action="dismiss"
              class="dismiss-btn"
            >Close</content.Trigger>
          </bs.Content>
        </DBottomSheet>
      </template>
    );

    assert.dom("[data-d-sheet~='view']").doesNotExist();
    assert.false(state.presented);

    await click(".btn");
    await waitFor(OPEN_VIEW_SELECTOR);

    assert.true(state.presented);
    assert.dom("[data-d-sheet~='view']").exists();

    await click(".dismiss-btn");
    await waitFor("[data-d-sheet~='view'][data-d-sheet~='closed']", {
      timeout: 3000,
    });

    const closedRect = find("[data-d-sheet~='view']").getBoundingClientRect();
    assert.true(
      closedRect.width <= 1,
      "the pending bottom sheet width is collapsed"
    );
    assert.true(
      closedRect.height <= 1,
      "the pending bottom sheet height is collapsed"
    );
    assert.false(state.presented, "the controlled state is dismissed");

    await waitUntil(() => !find("[data-d-sheet~='view']"), {
      timeout: 5000,
    });

    assert.false(state.presented);
    assert.dom("[data-d-sheet~='view']").doesNotExist();
  });

  test("@expandable shows expandable sheet", async function (assert) {
    await render(
      <template>
        <DBottomSheet @expandable={{true}} as |bs|>
          <bs.Trigger>Open</bs.Trigger>
          <bs.Content>
            <p>Content</p>
          </bs.Content>
        </DBottomSheet>
      </template>
    );

    await click(".btn");
    await waitFor(OPEN_VIEW_SELECTOR);

    assert.dom("[data-d-sheet~='view']").exists();
    assert.dom(".bottom-sheet__content.--expandable").exists();
    assert
      .dom(".bottom-sheet__view.--expandable")
      .exists("the expandable View exposes its layout variant");

    const view = find(".bottom-sheet__view");
    const viewStyle = getComputedStyle(view);
    assert.strictEqual(
      viewStyle.top,
      "0px",
      "the expandable View starts at the top"
    );
    assert.true(
      view.getBoundingClientRect().bottom > window.innerHeight,
      "the expandable View extends below the layout viewport"
    );
  });

  test("travel only dismisses the keyboard after expansion", async function (assert) {
    await render(
      <template>
        <DBottomSheet
          @componentId="keyboard-sheet"
          @defaultPresented={{true}}
          @expandable={{true}}
          as |bs|
        >
          <bs.Content as |content|>
            <input aria-label="Keyboard target" class="keyboard-target" />
            {{#if content.isExpanded}}
              <span data-expanded></span>
            {{/if}}
          </bs.Content>
        </DBottomSheet>
      </template>
    );

    await waitFor(
      ".bottom-sheet__view[data-d-sheet~='staging-none']:not([data-d-sheet~='closed'])"
    );

    const root = this.owner
      .lookup("service:sheet-layer-store")
      .getRootByComponentId("keyboard-sheet");
    const inputElement = find(".keyboard-target");
    const viewElement = find(".bottom-sheet__view");

    await focus(".keyboard-target");
    root.sheet.notifyTravel(0.5, [0, 1]);

    assert.strictEqual(
      document.activeElement,
      inputElement,
      "travel at the first detent leaves the text input focused"
    );

    root.sheet.setSegment([2, 2]);
    await waitFor("[data-expanded]");
    await settled();

    await focus(".keyboard-target");
    root.sheet.notifyTravel(0.5, [2, 1]);

    assert.strictEqual(
      document.activeElement,
      viewElement,
      "travel from the expanded detent moves focus to the View"
    );
  });

  test("expandable scroll areas fill the Root layout boundary", async function (assert) {
    await render(
      <template>
        <DBottomSheet @expandable={{true}} as |bs|>
          <bs.Trigger>Open</bs.Trigger>
          <bs.Content as |content|>
            <content.ScrollArea>
              <p>Scrollable content</p>
            </content.ScrollArea>
          </bs.Content>
        </DBottomSheet>
      </template>
    );

    await click(".btn");
    await waitFor(".bottom-sheet__scroll-view");

    const rootHeight = find(
      ".bottom-sheet__scroll-root"
    ).getBoundingClientRect().height;
    const viewHeight = find(
      ".bottom-sheet__scroll-view"
    ).getBoundingClientRect().height;

    assert.true(rootHeight > 0, "the Scroll Root receives the expandable row");
    assert.strictEqual(
      viewHeight,
      rootHeight,
      "the Scroll View fills its Root boundary"
    );
  });

  test("@onClosed is called when sheet closes", async function (assert) {
    let closedCalled = false;
    const onClosed = () => (closedCalled = true);

    await render(
      <template>
        <DBottomSheet @onClosed={{onClosed}} as |bs|>
          <bs.Trigger>Open</bs.Trigger>
          <bs.Content as |content|>
            <p>Content</p>
            <content.Trigger
              @action="dismiss"
              class="dismiss-btn"
            >Close</content.Trigger>
          </bs.Content>
        </DBottomSheet>
      </template>
    );

    await click(".btn");
    await waitFor(OPEN_VIEW_SELECTOR);
    await click(".dismiss-btn");
    await waitFor("[data-d-sheet~='view'][data-d-sheet~='closed']", {
      timeout: 3000,
    });

    const closedRect = find("[data-d-sheet~='view']").getBoundingClientRect();
    assert.true(
      closedRect.width <= 1,
      "the pending bottom sheet width is collapsed"
    );
    assert.true(
      closedRect.height <= 1,
      "the pending bottom sheet height is collapsed"
    );
    assert.false(closedCalled, "the callback waits until unmount is safe");

    await waitUntil(() => !find("[data-d-sheet~='view']"), {
      timeout: 5000,
    });

    assert.true(closedCalled);
  });
});
