import { tracked } from "@glimmer/tracking";
import { click, find, render, waitFor, waitUntil } from "@ember/test-helpers";
import { module, test } from "qunit";
import DBottomSheet from "discourse/float-kit/components/d-bottom-sheet";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | FloatKit | d-bottom-sheet", function (hooks) {
  setupRenderingTest(hooks);

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

    assert.dom("[data-d-sheet~='view']").exists();
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

    assert.dom("[data-d-sheet~='view']").exists();
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
    await waitFor("[data-d-sheet~='view']:not([data-d-sheet~='closed'])");
    await click(".dismiss-btn");
    await waitUntil(() => !find("[data-d-sheet~='view']"));

    assert.dom("[data-d-sheet~='view']").doesNotExist();
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
    await waitFor("[data-d-sheet~='view']:not([data-d-sheet~='closed'])");

    assert.true(state.presented);
    assert.dom("[data-d-sheet~='view']").exists();

    await click(".dismiss-btn");
    await waitUntil(() => !find("[data-d-sheet~='view']"));

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
    await waitFor("[data-d-sheet~='view']");

    assert.dom("[data-d-sheet~='view']").exists();
    assert.dom(".bottom-sheet__content.--expandable").exists();
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
    await waitFor("[data-d-sheet~='view']:not([data-d-sheet~='closed'])");
    await click(".dismiss-btn");
    await waitUntil(() => !find("[data-d-sheet~='view']"));

    assert.true(closedCalled);
  });
});
