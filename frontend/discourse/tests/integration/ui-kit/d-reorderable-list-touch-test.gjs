import { tracked } from "@glimmer/tracking";
import { find, render, settled, waitUntil } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { settledAfterFrame } from "discourse/tests/helpers/qunit-helpers";
import { centerOf } from "discourse/tests/helpers/ui-kit/drag-and-drop-helper";
import { stubPointerCapture } from "discourse/tests/helpers/ui-kit/pointer-gesture-helper";
import {
  dropCoordinates,
  label,
  List,
  MENU_SELECTOR,
  noop,
  objectItems,
} from "discourse/tests/helpers/ui-kit/reorderable-list-fixtures";
import {
  handleSelector,
  rowSelector,
} from "discourse/tests/helpers/ui-kit/reorderable-list-helper";
import DReorderableList from "discourse/ui-kit/d-reorderable-list";
import DReorderableListGroup from "discourse/ui-kit/d-reorderable-list-group";

const scrollItems = Array.from({ length: 10 }, (_, id) => ({
  id,
  name: String(id),
}));
const ScrollableList = <template>
  <DReorderableList
    style="height: 96px; overflow-y: auto; padding: 0;"
    ...attributes
    @group={{@group}}
    @items={{scrollItems}}
    @key="id"
    @label={{label}}
    @listId={{@listId}}
    @onMove={{@onMove}}
  >
    <:row as |item|><span style="height: 40px;">{{item.name}}</span></:row>
  </DReorderableList>
</template>;

function bottomEdge(element) {
  const { left, width, bottom } = element.getBoundingClientRect();
  return { clientX: left + width / 2, clientY: bottom - 2 };
}

function pressGrip(key, root) {
  const selector = handleSelector(key, root);
  const { element } = stubPointerCapture(selector);
  function dispatch(type, point) {
    return element.dispatchEvent(
      new PointerEvent(type, {
        pointerId: 42,
        pointerType: "touch",
        isPrimary: true,
        button: 0,
        bubbles: true,
        cancelable: true,
        ...point,
      })
    );
  }
  dispatch("pointerdown", centerOf(selector));
  return dispatch;
}

module("Integration | ui-kit | DReorderableList | touch", function (hooks) {
  setupRenderingTest(hooks);

  test("a held grip keeps its drag when the host replaces the rows", async function (assert) {
    const items = tracked(objectItems());
    const onMove = sinon.spy();
    await render(
      <template><List @items={{items.value}} @onMove={{onMove}} /></template>
    );

    const touch = pressGrip("alpha");
    const target = rowSelector("charlie");
    const point = dropCoordinates(target, "after");
    touch("pointermove", point);
    await settledAfterFrame();
    assert
      .dom(target)
      .hasClass("--drag-below", "the touch reaches the destination");

    items.value = objectItems();
    await settled();
    assert
      .dom(rowSelector("alpha"))
      .hasClass("--touch-dragging", "the refreshed row still owns the drag");
    assert
      .dom(target)
      .hasClass(
        "--drag-below",
        "the pending insertion point survives the refresh"
      );
    touch("pointerup", point);
    assert.strictEqual(onMove.callCount, 1, "release commits once");
    assert.strictEqual(
      onMove.firstCall.args[0].item,
      items.value[0],
      "the move resolves the refreshed item"
    );

    const grip = centerOf(handleSelector("alpha"));
    touch("pointerdown", grip);
    touch("pointerup", grip);
    touch("click", { detail: 1 });
    await settled();
    assert
      .dom(MENU_SELECTOR)
      .exists(
        "a fresh tap opens the menu even when the drag produced no click"
      );
  });

  test("a delayed click after a small touch drag leaves the move menu closed", async function (assert) {
    const items = objectItems();
    await render(
      <template><List @items={{items}} @onMove={{noop}} /></template>
    );

    const grip = handleSelector("alpha");
    const touch = pressGrip("alpha");
    const point = centerOf(grip);
    point.clientX += 6;
    touch("pointermove", point);
    assert
      .dom(rowSelector("alpha"))
      .hasClass("--touch-dragging", "six pixels starts a drag");
    touch("pointerup", point);
    await new Promise((resolve) => setTimeout(resolve, 0));
    touch("click", { ...point, detail: 1 });
    await settled();
    assert
      .dom(MENU_SELECTOR)
      .doesNotExist("the delayed click keeps the menu closed");
  });

  test("keyboard activation opens the move menu after a drag with no follow-up click", async function (assert) {
    const items = objectItems();
    await render(
      <template><List @items={{items}} @onMove={{noop}} /></template>
    );

    const touch = pressGrip("alpha");
    const point = dropCoordinates(rowSelector("bravo"), "after");
    touch("pointermove", point);
    touch("pointerup", point);
    find(handleSelector("alpha")).click();
    await settled();
    assert
      .dom(MENU_SELECTOR)
      .exists("the button accepts a zero-detail activation");
  });

  test("releasing before the next frame uses the release position and clears feedback", async function (assert) {
    const items = objectItems();
    const onMove = sinon.spy();
    await render(
      <template><List @items={{items}} @onMove={{onMove}} /></template>
    );

    const touch = pressGrip("alpha");
    touch("pointermove", dropCoordinates(rowSelector("bravo"), "after"));
    touch("pointerup", dropCoordinates(rowSelector("charlie"), "after"));
    await settledAfterFrame();

    assert.strictEqual(
      onMove.firstCall.args[0].toIndex,
      2,
      "the drop lands at the release point"
    );
    assert
      .dom(".--touch-dragging, .--drag-above, .--drag-below")
      .doesNotExist("a queued frame cannot restore cleared feedback");
  });

  test("a touch over a nested list falls through to its accepting outer row", async function (assert) {
    const items = objectItems();
    const innerItems = [{ id: "movable" }, { id: "frozen" }, { id: "other" }];
    const movable = (item) => item.id !== "frozen";
    const innerLabel = (item) => item.id;
    const onMove = sinon.spy();
    await render(
      <template>
        <DReorderableList
          @items={{items}}
          @key="id"
          @label={{label}}
          @onMove={{onMove}}
        >
          <:row as |item|>
            {{item.name}}
            {{#if (eq item.id "charlie")}}
              <DReorderableList
                @items={{innerItems}}
                @key="id"
                @label={{innerLabel}}
                @movable={{movable}}
                @onMove={{noop}}
              >
                <:row as |child|>{{child.id}}</:row>
              </DReorderableList>
            {{/if}}
          </:row>
        </DReorderableList>
      </template>
    );

    const touch = pressGrip("alpha");
    const outer = rowSelector("charlie");
    for (const key of ["movable", "frozen"]) {
      const point = centerOf(rowSelector(key));
      touch("pointermove", point);
      await settledAfterFrame();
      const { top, height } = find(outer).getBoundingClientRect();
      const expected =
        point.clientY < top + height / 2 ? "--drag-above" : "--drag-below";
      assert
        .dom(outer)
        .hasClass(
          expected,
          `the outer row accepts a drag over the ${key} inner row`
        );
    }
    touch("pointerup", centerOf(rowSelector("frozen")));
    assert.false(
      touch("click", { detail: 1 }),
      "the click immediately following the drag is consumed"
    );
    assert.strictEqual(
      onMove.callCount,
      1,
      "release moves the outer item once"
    );
  });

  test("holding a touch at the edge scrolls to an initially hidden drop target", async function (assert) {
    const onMove = sinon.spy();
    await render(<template><ScrollableList @onMove={{onMove}} /></template>);

    const scroller = find(".d-reorderable-list");
    const last = find(rowSelector("9"));
    assert.true(
      last.getBoundingClientRect().top >
        scroller.getBoundingClientRect().bottom,
      "the last row starts below the scrollport"
    );
    const touch = pressGrip("0");
    const point = bottomEdge(scroller);
    touch("pointermove", point);
    await waitUntil(() => last.classList.contains("--drag-below"), {
      timeout: 3000,
    });
    touch("pointerup", point);

    assert.strictEqual(
      onMove.firstCall.args[0].toIndex,
      9,
      "release places the first row last"
    );
    assert
      .dom(last)
      .doesNotHaveClass("--drag-below", "release clears the indicator");
  });

  test("crossing between grouped lists scrolls the list under the finger", async function (assert) {
    await render(
      <template>
        <DReorderableListGroup @onMove={{noop}} as |group|>
          <ScrollableList id="first" @group={{group}} @listId="first" />
          <ScrollableList id="second" @group={{group}} @listId="second" />
        </DReorderableListGroup>
      </template>
    );
    const first = find("#first");
    const second = find("#second");
    const touch = pressGrip("0", "#first");
    touch("pointermove", bottomEdge(first));
    await waitUntil(() => first.scrollTop > 0);
    const firstOffset = first.scrollTop;
    touch("pointermove", bottomEdge(second));
    await waitUntil(() => second.scrollTop > 0);
    assert.strictEqual(
      first.scrollTop,
      firstOffset,
      "only the destination list continues scrolling"
    );
    touch("pointercancel");
  });

  test("cancelling an upward edge drag stops the scroll and clears feedback", async function (assert) {
    const onMove = sinon.spy();
    await render(<template><ScrollableList @onMove={{onMove}} /></template>);
    const scroller = find(".d-reorderable-list");
    scroller.scrollTop = scroller.scrollHeight;
    const start = scroller.scrollTop;
    const bounds = scroller.getBoundingClientRect();
    const point = {
      clientX: bounds.left + bounds.width / 2,
      clientY: bounds.top + 2,
    };

    const touch = pressGrip("9");
    touch("pointermove", point);
    await waitUntil(() => scroller.scrollTop < start);
    touch("pointercancel", point);
    const cancelledAt = scroller.scrollTop;
    await settledAfterFrame();
    assert.strictEqual(
      scroller.scrollTop,
      cancelledAt,
      "scrolling stops on cancellation"
    );
    assert
      .dom(".--touch-dragging, .--drag-above, .--drag-below")
      .doesNotExist("cancellation clears both drag indicators");
    assert.false(onMove.called, "cancelling does not move an item");
  });
});
