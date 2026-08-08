import { tracked } from "@glimmer/tracking";
import {
  click,
  find,
  findAll,
  render,
  settled,
  triggerKeyEvent,
  waitFor,
  waitUntil,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import DSheet from "discourse/float-kit/components/d-sheet";
import DStack from "discourse/float-kit/components/d-stack";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | FloatKit | d-stack", function (hooks) {
  setupRenderingTest(hooks);

  test("opens when trigger is clicked", async function (assert) {
    await render(
      <template>
        <DStack as |stack|>
          <stack.Trigger>Open</stack.Trigger>
          <stack.Content as |content|>
            <p>Content</p>
            <content.Trigger @action="dismiss">Close</content.Trigger>
          </stack.Content>
        </DStack>
      </template>
    );

    assert.dom(".d-stack__view").doesNotExist();

    await click(".btn");
    await waitFor(".d-stack__view");
    await new Promise((resolve) => setTimeout(resolve, 750));

    assert.dom(".d-stack__view").isVisible("the settled stack remains visible");
    assert.notStrictEqual(
      getComputedStyle(find(".d-stack__view")).opacity,
      "0",
      "the settled stack remains opaque"
    );
  });

  test("opens by default with @defaultPresented", async function (assert) {
    await render(
      <template>
        <DStack @defaultPresented={{true}} as |stack|>
          <stack.Content as |content|>
            <p>Content</p>
            <content.Trigger @action="dismiss">Close</content.Trigger>
          </stack.Content>
        </DStack>
      </template>
    );

    await waitFor(".d-stack__view");

    assert
      .dom(".d-stack__view")
      .hasAttribute("role", "dialog", "the stack preset is a dialog");
  });

  test("closes when dismiss trigger is clicked", async function (assert) {
    await render(
      <template>
        <DStack as |stack|>
          <stack.Trigger>Open</stack.Trigger>
          <stack.Content as |content|>
            <p>Content</p>
            <content.Trigger
              @action="dismiss"
              class="dismiss-btn"
            >Close</content.Trigger>
          </stack.Content>
        </DStack>
      </template>
    );

    await click(".btn");
    await waitFor("[data-d-sheet~='view']:not([data-d-sheet~='closed'])");
    await click(".dismiss-btn");
    await waitFor(".d-stack__view[data-d-sheet~='closed']", {
      timeout: 3000,
    });

    const closedRect = find(".d-stack__view").getBoundingClientRect();
    assert.true(closedRect.width <= 1, "the pending stack width is collapsed");
    assert.true(
      closedRect.height <= 1,
      "the pending stack height is collapsed"
    );

    await waitUntil(() => !find(".d-stack__view"), { timeout: 5000 });

    assert.dom(".d-stack__view").doesNotExist();
  });

  test("renders backdrop when open", async function (assert) {
    await render(
      <template>
        <DStack as |stack|>
          <stack.Trigger>Open</stack.Trigger>
          <stack.Content>
            <p>Content</p>
          </stack.Content>
        </DStack>
      </template>
    );

    await click(".btn");
    await waitFor(".d-stack__view");

    assert.dom(".d-stack__view").exists();
    assert.dom("[data-d-sheet~='backdrop']").exists();
  });

  test("controlled mode with @presented and @onPresentedChange", async function (assert) {
    const state = new (class {
      @tracked presented = false;
    })();

    const onPresentedChange = (value) => (state.presented = value);

    await render(
      <template>
        <DStack
          @presented={{state.presented}}
          @onPresentedChange={{onPresentedChange}}
          as |stack|
        >
          <stack.Trigger>Open</stack.Trigger>
          <stack.Content as |content|>
            <p>Content</p>
            <content.Trigger
              @action="dismiss"
              class="dismiss-btn"
            >Close</content.Trigger>
          </stack.Content>
        </DStack>
      </template>
    );

    assert.dom(".d-stack__view").doesNotExist();
    assert.false(state.presented);

    await click(".btn");
    await waitFor("[data-d-sheet~='view']:not([data-d-sheet~='closed'])");

    assert.true(state.presented);
    assert.dom(".d-stack__view").exists();

    await click(".dismiss-btn");
    await waitFor(".d-stack__view[data-d-sheet~='closed']", {
      timeout: 3000,
    });

    const closedRect = find(".d-stack__view").getBoundingClientRect();
    assert.true(closedRect.width <= 1, "the pending stack width is collapsed");
    assert.true(
      closedRect.height <= 1,
      "the pending stack height is collapsed"
    );
    assert.false(state.presented, "the controlled state is dismissed");

    await waitUntil(() => !find(".d-stack__view"), { timeout: 5000 });

    assert.false(state.presented);
    assert.dom(".d-stack__view").doesNotExist();
  });

  test("closes on escape key", async function (assert) {
    await render(
      <template>
        <DStack as |stack|>
          <stack.Trigger>Open</stack.Trigger>
          <stack.Content>
            <p>Content</p>
          </stack.Content>
        </DStack>
      </template>
    );

    await click(".btn");
    await waitFor("[data-d-sheet~='view']:not([data-d-sheet~='closed'])");

    assert.dom(".d-stack__view").exists();

    await triggerKeyEvent(document, "keydown", "Escape");
    await waitFor(".d-stack__view[data-d-sheet~='closed']", {
      timeout: 3000,
    });

    const closedRect = find(".d-stack__view").getBoundingClientRect();
    assert.true(closedRect.width <= 1, "the pending stack width is collapsed");
    assert.true(
      closedRect.height <= 1,
      "the pending stack height is collapsed"
    );

    await waitUntil(() => !find(".d-stack__view"), { timeout: 5000 });

    assert.dom(".d-stack__view").doesNotExist();
  });

  test("@onClosed is called when sheet closes", async function (assert) {
    let closedCalled = false;
    const onClosed = () => (closedCalled = true);

    await render(
      <template>
        <DStack @onClosed={{onClosed}} as |stack|>
          <stack.Trigger>Open</stack.Trigger>
          <stack.Content as |content|>
            <p>Content</p>
            <content.Trigger
              @action="dismiss"
              class="dismiss-btn"
            >Close</content.Trigger>
          </stack.Content>
        </DStack>
      </template>
    );

    await click(".btn");
    await waitFor("[data-d-sheet~='view']:not([data-d-sheet~='closed'])");
    await click(".dismiss-btn");
    await waitFor(".d-stack__view[data-d-sheet~='closed']", {
      timeout: 3000,
    });

    const closedRect = find(".d-stack__view").getBoundingClientRect();
    assert.true(closedRect.width <= 1, "the pending stack width is collapsed");
    assert.true(
      closedRect.height <= 1,
      "the pending stack height is collapsed"
    );
    assert.false(closedCalled, "the callback waits until unmount is safe");

    await waitUntil(() => !find(".d-stack__view"), { timeout: 5000 });

    assert.true(closedCalled);
  });

  test("tracks based on viewport width", async function (assert) {
    await render(
      <template>
        <DStack as |stack|>
          <stack.Trigger>Open</stack.Trigger>
          <stack.Content>
            <p>Content</p>
          </stack.Content>
        </DStack>
      </template>
    );

    await click(".btn");
    await waitFor(".d-stack__view");

    assert
      .dom("[data-d-sheet~='view']")
      .hasAttribute("data-d-sheet", /bottom|right/);
  });

  test("nested stack opens on top of parent", async function (assert) {
    await render(
      <template>
        <DStack as |stack|>
          <stack.Trigger class="open-parent">Open</stack.Trigger>
          <stack.Content as |content|>
            <p>Parent content</p>
            <content.Stack as |nested|>
              <nested.Trigger class="open-nested">Open Nested</nested.Trigger>
              <nested.Content as |nestedContent|>
                <p>Nested content</p>
                <nestedContent.Trigger
                  @action="dismiss"
                  class="close-nested"
                >Close Nested</nestedContent.Trigger>
              </nested.Content>
            </content.Stack>
            <content.Trigger
              @action="dismiss"
              class="close-parent"
            >Close</content.Trigger>
          </stack.Content>
        </DStack>
      </template>
    );

    await click(".open-parent");
    await waitFor("[data-d-sheet~='view']:not([data-d-sheet~='closed'])");
    await waitUntil(
      () =>
        find(".d-stack__view")?.dataset.dSheet.includes("staging-none") &&
        find(".d-stack__content")?.getBoundingClientRect().left <
          find(".d-stack__view")?.getBoundingClientRect().right,
      { timeout: 3000 }
    );

    assert.dom(".d-stack__view").exists({ count: 1 });

    await click(".open-nested");
    await waitFor(".close-nested");

    assert.dom(".d-stack__view").exists({ count: 2 });
  });

  test("closing nested stack returns to parent", async function (assert) {
    await render(
      <template>
        <DStack as |stack|>
          <stack.Trigger class="open-parent">Open</stack.Trigger>
          <stack.Content as |content|>
            <p>Parent content</p>
            <content.Stack as |nested|>
              <nested.Trigger class="open-nested">Open Nested</nested.Trigger>
              <nested.Content as |nestedContent|>
                <p>Nested content</p>
                <nestedContent.Trigger
                  @action="dismiss"
                  class="close-nested"
                >Close Nested</nestedContent.Trigger>
              </nested.Content>
            </content.Stack>
            <content.Trigger
              @action="dismiss"
              class="close-parent"
            >Close</content.Trigger>
          </stack.Content>
        </DStack>
      </template>
    );

    await click(".open-parent");
    await waitFor("[data-d-sheet~='view']:not([data-d-sheet~='closed'])");
    await waitUntil(
      () => {
        const contentRect = find(".d-stack__content")?.getBoundingClientRect();
        const view = find(".d-stack__view");
        const viewRect = view?.getBoundingClientRect();

        return Boolean(
          view &&
          viewRect &&
          contentRect &&
          view.dataset.dSheet.includes("staging-none") &&
          contentRect.left < viewRect.right &&
          contentRect.right > viewRect.left
        );
      },
      { timeout: 3000 }
    );

    const parentView = find(".d-stack__view");
    const parentContent = find(".d-stack__content");
    const parentScrollContainer = parentContent.closest(
      "[data-d-sheet~='scroll-container']"
    );
    const paintedFrameFailures = [];
    let nestedWasVisible = false;
    assert.true(
      parentView.dataset.dSheet.includes("right"),
      "the regression exercises the horizontal desktop stack"
    );
    assert.notStrictEqual(
      find(".open-nested").getAttribute("aria-controls"),
      parentView.id,
      "the nested trigger targets its own sheet"
    );
    assert.true(
      parentContent.contains(find(".open-nested")),
      "the nested trigger remains inside the parent content"
    );
    let monitorFrame;
    const monitorParent = () => {
      const contentRect = parentContent.getBoundingClientRect();
      const viewRect = parentView.getBoundingClientRect();
      const intersectionWidth = Math.max(
        0,
        Math.min(contentRect.right, viewRect.right) -
          Math.max(contentRect.left, viewRect.left)
      );
      const intersectionHeight = Math.max(
        0,
        Math.min(contentRect.bottom, viewRect.bottom) -
          Math.max(contentRect.top, viewRect.top)
      );

      if (
        paintedFrameFailures.length === 0 &&
        (!parentView.isConnected ||
          !parentContent.isConnected ||
          !parentScrollContainer.isConnected ||
          parentView.dataset.dSheet.includes("closed") ||
          getComputedStyle(parentView).opacity === "0" ||
          intersectionWidth * intersectionHeight === 0)
      ) {
        paintedFrameFailures.push({
          contentRect,
          scrollLeft: parentScrollContainer.scrollLeft,
          viewRect,
          viewTokens: parentView.dataset.dSheet,
        });
      }

      const nestedView = findAll(".d-stack__view")[1];
      const nestedContent = nestedView?.querySelector(".d-stack__content");
      if (nestedView && nestedContent) {
        const nestedContentRect = nestedContent.getBoundingClientRect();
        const nestedViewRect = nestedView.getBoundingClientRect();
        const nestedIntersection =
          Math.max(
            0,
            Math.min(nestedContentRect.right, nestedViewRect.right) -
              Math.max(nestedContentRect.left, nestedViewRect.left)
          ) *
          Math.max(
            0,
            Math.min(nestedContentRect.bottom, nestedViewRect.bottom) -
              Math.max(nestedContentRect.top, nestedViewRect.top)
          );
        const nestedIsVisible =
          !nestedView.dataset.dSheet.includes("closed") &&
          getComputedStyle(nestedView).opacity !== "0" &&
          nestedIntersection > 0;

        if (nestedWasVisible && !nestedIsVisible) {
          paintedFrameFailures.push({
            nestedContentRect,
            nestedViewRect,
            nestedViewTokens: nestedView.dataset.dSheet,
          });
        }
        nestedWasVisible ||= nestedIsVisible;
      }

      monitorFrame = requestAnimationFrame(monitorParent);
    };

    monitorFrame = requestAnimationFrame(monitorParent);
    try {
      await click(".open-nested");
      await waitFor(".close-nested");
      await waitUntil(
        () =>
          findAll(
            ".d-stack__view[data-d-sheet~='staging-none']:not([data-d-sheet~='closed'])"
          ).length === 2,
        { timeout: 3000 }
      );
      await new Promise((resolve) => requestAnimationFrame(resolve));
    } finally {
      cancelAnimationFrame(monitorFrame);
    }

    assert.deepEqual(
      paintedFrameFailures,
      [],
      "the parent remains rendered and intersecting throughout nested opening"
    );
    assert.false(
      parentView.dataset.dSheet.includes("closed"),
      "the parent remains open after nested presentation"
    );
    assert.dom(".d-stack__view").exists({ count: 2 });

    const nestedView = find(".close-nested").closest("[data-d-sheet~='view']");
    await click(".close-nested");
    await waitUntil(() => nestedView.dataset.dSheet.includes("closed"), {
      timeout: 3000,
    });

    const closedRect = nestedView.getBoundingClientRect();
    assert.true(
      closedRect.width <= 1,
      "the pending nested stack width is collapsed"
    );
    assert.true(
      closedRect.height <= 1,
      "the pending nested stack height is collapsed"
    );
    assert
      .dom(".d-stack__view")
      .exists({ count: 2 }, "the nested view remains mounted while pending");
    assert.false(
      parentView.dataset.dSheet.includes("closed"),
      "the parent remains open"
    );

    await waitUntil(() => findAll(".d-stack__view").length === 1, {
      timeout: 5000,
    });

    assert
      .dom(".d-stack__view")
      .exists({ count: 1 }, "only the parent remains after pending closes");
    assert.false(
      parentView.dataset.dSheet.includes("closed"),
      "the parent is still open after the nested sheet unmounts"
    );
  });

  test("forwards attributes to the root", async function (assert) {
    await render(
      <template>
        <DStack class="custom-stack-root" data-test-stack-root as |stack|>
          <stack.Content>
            <p>Content</p>
          </stack.Content>
        </DStack>
      </template>
    );

    assert
      .dom("[data-d-sheet~='root'].custom-stack-root")
      .exists("custom classes are forwarded");
    assert
      .dom("[data-d-sheet~='root']")
      .hasAttribute(
        "data-test-stack-root",
        "",
        "custom attributes are forwarded"
      );
  });

  test("exports a stack outlet", async function (assert) {
    await render(
      <template>
        <DSheet.Stack.Root as |stack|>
          <stack.Outlet class="custom-stack-outlet">
            Main content
          </stack.Outlet>
        </DSheet.Stack.Root>
      </template>
    );

    assert
      .dom("[data-d-sheet-stack~='outlet'].custom-stack-outlet")
      .hasText("Main content", "the yielded stack outlet renders");
  });

  test("renders the stack root and preserves consumer tokens", async function (assert) {
    await render(
      <template>
        <DSheet.Stack.Root
          class="custom-stack-provider"
          data-d-sheet-stack="consumer-root"
          data-test-stack-provider
          as |stack|
        >
          <stack.Outlet data-d-sheet-stack="consumer-outlet">
            Main content
          </stack.Outlet>
        </DSheet.Stack.Root>
      </template>
    );

    assert
      .dom(".custom-stack-provider[data-d-sheet-stack~='root']")
      .hasAttribute(
        "data-d-sheet-stack",
        /consumer-root/,
        "the stack root merges consumer and structural tokens"
      )
      .hasAttribute(
        "data-test-stack-provider",
        "",
        "the stack root forwards attributes"
      );
    assert
      .dom("[data-d-sheet-stack~='outlet']")
      .hasAttribute(
        "data-d-sheet-stack",
        /consumer-outlet/,
        "the stack outlet preserves consumer tokens"
      );
  });

  test("keeps stack outlet animation registration stable while staging changes", async function (assert) {
    const stackId = "stable-animation-stack";
    const stackingAnimation = { opacity: [1, 0] };
    const registry = this.owner.lookup("service:sheet-stack-registry");

    await render(
      <template>
        <DSheet.Stack.Root @componentId={{stackId}} as |stack|>
          <stack.Outlet @stackingAnimation={{stackingAnimation}}>
            Main content
          </stack.Outlet>
        </DSheet.Stack.Root>
      </template>
    );

    const registeredStack = registry.stacks.get(stackId);
    const initialRegistration = registeredStack.stackingAnimations[0];

    registry.updateSheetStagingInStack(stackId, "sheet-id", "opening");
    await settled();

    assert
      .dom("[data-d-sheet-stack~='outlet']")
      .hasAttribute(
        "data-d-sheet-stack",
        /animating/,
        "the outlet reflects the staging update"
      );
    assert.strictEqual(
      registeredStack.stackingAnimations.length,
      1,
      "the outlet keeps one animation registration"
    );
    assert.strictEqual(
      registeredStack.stackingAnimations[0],
      initialRegistration,
      "the staging-only render does not replace the animation registration"
    );
  });
});
