import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DReorderButtons from "discourse/ui-kit/d-reorder-buttons";

module("Integration | ui-kit | DReorderButtons", function (hooks) {
  setupRenderingTest(hooks);

  test("each button moves in its own direction", async function (assert) {
    const calls = [];
    const up = () => calls.push("up");
    const down = () => calls.push("down");

    await render(
      <template>
        <DReorderButtons
          @onMoveUp={{up}}
          @onMoveDown={{down}}
          @upLabel="Move up"
          @downLabel="Move down"
        />
      </template>
    );

    await click(".d-reorder-buttons__button:first-child");
    await click(".d-reorder-buttons__button:last-child");

    assert.deepEqual(calls, ["up", "down"], "up is first, down is second");
  });

  test("the labels name the item for both pointer and screen reader", async function (assert) {
    const noop = () => {};

    await render(
      <template>
        <DReorderButtons
          @onMoveUp={{noop}}
          @onMoveDown={{noop}}
          @upLabel="Move Reports up"
          @downLabel="Move Reports down"
        />
      </template>
    );

    assert
      .dom(".d-reorder-buttons__button:first-child")
      .hasAria("label", "Move Reports up")
      .hasAttribute(
        "title",
        "Move Reports up",
        "the tooltip repeats the accessible name, so both audiences are told the same thing"
      );
    assert
      .dom(".d-reorder-buttons__button:last-child")
      .hasAria("label", "Move Reports down");
  });

  test("each end of the list disables only its own direction", async function (assert) {
    const noop = () => {};

    await render(
      <template>
        <DReorderButtons
          @onMoveUp={{noop}}
          @onMoveDown={{noop}}
          @disableUp={{true}}
          @disableDown={{false}}
          @upLabel="Move up"
          @downLabel="Move down"
        />
      </template>
    );

    assert.dom(".d-reorder-buttons__button:first-child").isDisabled();
    assert.dom(".d-reorder-buttons__button:last-child").isNotDisabled();
  });

  test("keeps the tab order, so the pair is the keyboard path", async function (assert) {
    const noop = () => {};

    await render(
      <template>
        <DReorderButtons
          @onMoveUp={{noop}}
          @onMoveDown={{noop}}
          @upLabel="Move up"
          @downLabel="Move down"
        />
      </template>
    );

    assert
      .dom(".d-reorder-buttons__button:first-child")
      .doesNotHaveAttribute(
        "tabindex",
        "the buttons keep their native tab stop"
      );
  });

  test("attributes pass through so a consumer keeps its own class", async function (assert) {
    const noop = () => {};

    await render(
      <template>
        <DReorderButtons
          @onMoveUp={{noop}}
          @onMoveDown={{noop}}
          @upLabel="Move up"
          @downLabel="Move down"
          class="my-block__arrows"
          data-test-marker="present"
        />
      </template>
    );

    assert
      .dom(".d-reorder-buttons")
      .hasClass(
        "my-block__arrows",
        "the consumer's class lands alongside the block's own"
      )
      .hasAttribute("data-test-marker", "present");
  });
});
