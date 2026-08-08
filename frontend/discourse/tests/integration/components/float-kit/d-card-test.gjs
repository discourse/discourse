import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import {
  click,
  find,
  render,
  triggerKeyEvent,
  waitFor,
  waitUntil,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import DCard from "discourse/float-kit/components/d-card";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | FloatKit | d-card", function (hooks) {
  setupRenderingTest(hooks);

  test("opens when trigger is clicked", async function (assert) {
    await render(
      <template>
        <DCard as |card|>
          <card.Trigger>Open</card.Trigger>
          <card.Content as |content|>
            <p>Content</p>
            <content.Trigger @action="dismiss">Close</content.Trigger>
          </card.Content>
        </DCard>
      </template>
    );

    assert.dom(".d-card").doesNotExist();

    await click(".btn");
    await waitFor(".d-card");

    assert.dom(".d-card").exists("the card opens");

    assert
      .dom(".btn")
      .hasAttribute("aria-controls", /.+/, "the trigger has aria-controls");
    const controlsId = find(".btn").getAttribute("aria-controls");
    assert
      .dom(`#${CSS.escape(controlsId)}`)
      .exists("the trigger aria-controls target exists");
  });

  test("opens by default with @defaultPresented", async function (assert) {
    await render(
      <template>
        <DCard @defaultPresented={{true}} as |card|>
          <card.Content as |content|>
            <p>Content</p>
            <content.Trigger @action="dismiss">Close</content.Trigger>
          </card.Content>
        </DCard>
      </template>
    );

    await waitFor(".d-card");
    await new Promise((resolve) => setTimeout(resolve, 750));

    assert
      .dom(".d-card")
      .hasAttribute("role", "dialog", "the card preset is a dialog")
      .isVisible("the settled card remains visible");
    assert.notStrictEqual(
      getComputedStyle(find(".d-card")).opacity,
      "0",
      "the settled card remains opaque"
    );
  });

  test("closes when dismiss trigger is clicked", async function (assert) {
    await render(
      <template>
        <DCard as |card|>
          <card.Trigger>Open</card.Trigger>
          <card.Content as |content|>
            <p>Content</p>
            <content.Trigger
              @action="dismiss"
              class="dismiss-btn"
            >Close</content.Trigger>
          </card.Content>
        </DCard>
      </template>
    );

    await click(".btn");
    await waitFor("[data-d-sheet~='view']:not([data-d-sheet~='closed'])");
    await click(".dismiss-btn");
    await waitFor(".d-card[data-d-sheet~='closed']", { timeout: 3000 });

    const closedRect = find(".d-card").getBoundingClientRect();
    assert.true(closedRect.width <= 1, "the pending card width is collapsed");
    assert.true(closedRect.height <= 1, "the pending card height is collapsed");

    await waitUntil(() => !find(".d-card"), { timeout: 5000 });

    assert.dom(".d-card").doesNotExist();
  });

  test("renders backdrop when open", async function (assert) {
    await render(
      <template>
        <DCard as |card|>
          <card.Trigger>Open</card.Trigger>
          <card.Content>
            <p>Content</p>
          </card.Content>
        </DCard>
      </template>
    );

    await click(".btn");
    await waitFor(".d-card");
    await waitUntil(
      () => find("[data-d-sheet~='backdrop']")?.style.opacity === "0.4",
      { timeout: 3000 }
    );

    assert.dom(".d-card").exists();
    assert
      .dom("[data-d-sheet~='backdrop']")
      .hasStyle(
        { opacity: "0.4" },
        "the card applies its configured backdrop animation"
      );
  });

  test("controlled mode with @presented and @onPresentedChange", async function (assert) {
    const state = new (class {
      @tracked presented = false;
    })();
    const changes = [];

    const onPresentedChange = (value) => {
      changes.push(value);
      state.presented = value;
    };

    await render(
      <template>
        <DCard
          @presented={{state.presented}}
          @onPresentedChange={{onPresentedChange}}
          as |card|
        >
          <card.Trigger>Open</card.Trigger>
          <card.Content as |content|>
            <p>Content</p>
            <content.Trigger
              @action="dismiss"
              class="dismiss-btn"
            >Close</content.Trigger>
          </card.Content>
        </DCard>
      </template>
    );

    assert.dom(".d-card").doesNotExist();
    assert.false(state.presented);

    await click(".btn");
    await waitFor("[data-d-sheet~='view']:not([data-d-sheet~='closed'])");

    assert.true(state.presented);
    assert.dom(".d-card").exists();

    await click(".dismiss-btn");
    await waitFor(".d-card[data-d-sheet~='closed']", { timeout: 3000 });

    const closedRect = find(".d-card").getBoundingClientRect();
    assert.true(closedRect.width <= 1, "the pending card width is collapsed");
    assert.true(closedRect.height <= 1, "the pending card height is collapsed");
    assert.false(state.presented, "the controlled state is dismissed");

    await waitUntil(() => !find(".d-card"), { timeout: 5000 });

    assert.false(state.presented);
    assert.dom(".d-card").doesNotExist();
    assert.deepEqual(
      changes,
      [true, false],
      "controlled mode emits a single change for each state transition"
    );
  });

  test("yielded actions open and close through the root lifecycle", async function (assert) {
    await render(
      <template>
        <DCard as |card|>
          <button type="button" class="present-btn" {{on "click" card.present}}>
            Present
          </button>
          <button type="button" class="dismiss-btn" {{on "click" card.dismiss}}>
            Dismiss
          </button>
          <card.Content>
            <p>Content</p>
          </card.Content>
        </DCard>
      </template>
    );

    await click(".present-btn");
    await waitFor("[data-d-sheet~='view']:not([data-d-sheet~='closed'])");

    assert.dom(".d-card").exists("the yielded present action opens the card");

    await click(".dismiss-btn");
    await waitFor(".d-card[data-d-sheet~='closed']", { timeout: 3000 });

    const closedRect = find(".d-card").getBoundingClientRect();
    assert.true(closedRect.width <= 1, "the pending card width is collapsed");
    assert.true(closedRect.height <= 1, "the pending card height is collapsed");

    await waitUntil(() => !find(".d-card"), { timeout: 5000 });

    assert
      .dom(".d-card")
      .doesNotExist("the yielded dismiss action closes the card");
  });

  test("closes on escape key", async function (assert) {
    await render(
      <template>
        <DCard as |card|>
          <card.Trigger>Open</card.Trigger>
          <card.Content>
            <p>Content</p>
          </card.Content>
        </DCard>
      </template>
    );

    await click(".btn");
    await waitFor("[data-d-sheet~='view']:not([data-d-sheet~='closed'])");

    assert.dom(".d-card").exists();

    await triggerKeyEvent(document, "keydown", "Escape");
    await waitFor(".d-card[data-d-sheet~='closed']", { timeout: 3000 });

    const closedRect = find(".d-card").getBoundingClientRect();
    assert.true(closedRect.width <= 1, "the pending card width is collapsed");
    assert.true(closedRect.height <= 1, "the pending card height is collapsed");

    await waitUntil(() => !find(".d-card"), { timeout: 5000 });

    assert.dom(".d-card").doesNotExist();
  });

  test("@onClosed is called when sheet closes", async function (assert) {
    let closedCalled = false;
    const onClosed = () => (closedCalled = true);

    await render(
      <template>
        <DCard @onClosed={{onClosed}} as |card|>
          <card.Trigger>Open</card.Trigger>
          <card.Content as |content|>
            <p>Content</p>
            <content.Trigger
              @action="dismiss"
              class="dismiss-btn"
            >Close</content.Trigger>
          </card.Content>
        </DCard>
      </template>
    );

    await click(".btn");
    await waitFor("[data-d-sheet~='view']:not([data-d-sheet~='closed'])");
    await click(".dismiss-btn");
    await waitFor(".d-card[data-d-sheet~='closed']", { timeout: 3000 });

    const closedRect = find(".d-card").getBoundingClientRect();
    assert.true(closedRect.width <= 1, "the pending card width is collapsed");
    assert.true(closedRect.height <= 1, "the pending card height is collapsed");
    assert.false(closedCalled, "the callback waits until unmount is safe");

    await waitUntil(() => !find(".d-card"), { timeout: 5000 });

    assert.true(closedCalled);
  });

  test("uses top track by default", async function (assert) {
    await render(
      <template>
        <DCard as |card|>
          <card.Trigger>Open</card.Trigger>
          <card.Content>
            <p>Content</p>
          </card.Content>
        </DCard>
      </template>
    );

    await click(".btn");
    await waitFor(".d-card");

    assert.dom("[data-d-sheet~='view'][data-d-sheet~='top']").exists();
  });

  test("forwards attributes to the root", async function (assert) {
    await render(
      <template>
        <DCard class="custom-card-root" data-test-card-root as |card|>
          <card.Content>
            <p>Content</p>
          </card.Content>
        </DCard>
      </template>
    );

    assert
      .dom("[data-d-sheet~='root'].custom-card-root")
      .exists("custom classes are forwarded");
    assert
      .dom("[data-d-sheet~='root']")
      .hasAttribute(
        "data-test-card-root",
        "",
        "custom attributes are forwarded"
      );
  });
});
