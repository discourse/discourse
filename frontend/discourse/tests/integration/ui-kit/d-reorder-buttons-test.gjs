import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
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
    const calls = [];
    const onMoveUp = () => calls.push("up");
    const onMoveDown = () => calls.push("down");

    await render(
      <template>
        <DReorderButtons
          @onMoveUp={{onMoveUp}}
          @onMoveDown={{onMoveDown}}
          @disableUp={{true}}
          @disableDown={{false}}
          @upLabel="Move up"
          @downLabel="Move down"
        />
      </template>
    );

    // Marked unavailable rather than carrying the `disabled` attribute, so the
    // button keeps its place in the tab order at the ends of the list. The
    // component is what refuses the press, which is why that is asserted too.
    assert
      .dom(".d-reorder-buttons__button:first-child")
      .hasAttribute("aria-disabled", "true")
      .isNotDisabled();
    assert
      .dom(".d-reorder-buttons__button:last-child")
      .doesNotHaveAttribute("aria-disabled")
      .isNotDisabled();

    await click(".d-reorder-buttons__button:first-child");
    assert.deepEqual(
      calls,
      [],
      "pressing the unavailable direction does nothing"
    );

    await click(".d-reorder-buttons__button:last-child");
    assert.deepEqual(
      calls,
      ["down"],
      "while the available one still runs its callback"
    );
  });

  test("a press keeps its button focused across the re-render it causes", async function (assert) {
    // The real consumers move the pressed row inside a keyed list, and moving a
    // DOM node drops focus to the body. A bare component would pass this from
    // the click's own native focus alone, so the list is part of the fixture —
    // it is what makes the component's refocus observable.
    const state = new (class {
      @tracked items = ["a", "b"];
      move = () => (this.items = [...this.items].reverse());
    })();

    await render(
      <template>
        {{#each state.items key="@identity" as |item|}}
          <div data-item={{item}}>
            <DReorderButtons
              @onMoveUp={{fn state.move item}}
              @onMoveDown={{fn state.move item}}
              @upLabel="Move up"
              @downLabel="Move down"
            />
          </div>
        {{/each}}
      </template>
    );

    await click("[data-item='a'] .d-reorder-buttons__button:last-child");

    assert.strictEqual(state.items[1], "a", "the move happened");
    assert
      .dom("[data-item='a'] .d-reorder-buttons__button:last-child")
      .isFocused(
        "the pressed button is focused again after its row moved, so a keyboard user can keep going"
      );
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
