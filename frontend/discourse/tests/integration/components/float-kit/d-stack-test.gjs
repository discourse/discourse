import { tracked } from "@glimmer/tracking";
import {
  click,
  find,
  findAll,
  render,
  triggerKeyEvent,
  waitFor,
  waitUntil,
} from "@ember/test-helpers";
import { module, test } from "qunit";
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

    assert.dom(".d-stack__view").exists();
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

    assert.dom(".d-stack__view").exists();
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
    await waitUntil(() => !find(".d-stack__view"));

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
    await waitUntil(() => !find(".d-stack__view"));

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
    await waitUntil(() => !find(".d-stack__view"));

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
    await waitUntil(() => !find(".d-stack__view"));

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

    await click(".open-nested");
    await waitFor(".close-nested");
    await waitUntil(
      () =>
        findAll("[data-d-sheet~='view']:not([data-d-sheet~='closed'])")
          .length === 2
    );

    assert.dom(".d-stack__view").exists({ count: 2 });

    await click(".close-nested");
    await waitUntil(() => !find(".close-nested"));

    assert.dom(".d-stack__view").exists({ count: 1 });
  });
});
