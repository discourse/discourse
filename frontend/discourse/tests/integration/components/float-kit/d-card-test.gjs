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

    assert.dom(".d-card").exists();
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
    await waitUntil(() => !find(".d-card"));

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

    assert.dom(".d-card").exists();
    assert.dom("[data-d-sheet~='backdrop']").exists();
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
    await waitUntil(() => !find(".d-card"));

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
    await waitUntil(() => !find(".d-card"));

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
    await waitUntil(() => !find(".d-card"));

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
    await waitUntil(() => !find(".d-card"));

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
});
