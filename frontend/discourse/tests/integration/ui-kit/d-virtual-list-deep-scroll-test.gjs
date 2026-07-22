import { tracked } from "@glimmer/tracking";
import { find, render, settled, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DVirtualList from "discourse/ui-kit/d-virtual-list";
import {
  disableVirtualization,
  enableVirtualization,
} from "discourse/ui-kit/lib/virtualizer";

const ROW_PX = 44;
const estimate = () => ROW_PX;

class State {
  @tracked items;

  constructor(items) {
    this.items = items;
  }
}

function buildRows(count) {
  return Array.from({ length: count }, (_, index) => ({
    id: index,
    text: `Row ${index}`,
  }));
}

function styledCount() {
  return [...document.querySelectorAll(".d-virtual-list__item")].filter(
    (el) => el.style.transform && el.style.position === "absolute"
  ).length;
}

function unstyled() {
  return [...document.querySelectorAll(".d-virtual-list__item")]
    .filter((el) => !el.style.transform || el.style.position !== "absolute")
    .map((el) => el.dataset.index);
}

async function scrollTo(top) {
  const element = find(".d-virtual-list");
  element.scrollTop = top;
  await triggerEvent(element, "scroll");
}

module("Integration | ui-kit | DVirtualList | deep scroll", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    enableVirtualization();
  });

  hooks.afterEach(function () {
    disableVirtualization();
  });

  test("rows keep their absolute positioning across a keyed re-render", async function (assert) {
    const state = new State(buildRows(10000));

    await render(
      <template>
        {{! eslint-disable-next-line ember/template-no-forbidden-elements }}
        <style>
          .d-virtual-list {
            height: 400px;
            overflow-y: auto;
          }
        </style>
        <DVirtualList
          @items={{state.items}}
          @key="id"
          @estimateSize={{estimate}}
          @role="list"
          @itemRole="listitem"
          as |row|
        >
          <div style="height: 44px">{{row.text}}</div>
        </DVirtualList>
      </template>
    );

    await scrollTo(1500 * ROW_PX);
    assert.true(styledCount() > 0, "rows are positioned after scrolling deep");

    // A keyed re-render (same ids, fresh objects) reuses the row elements but
    // churns the per-row positioning modifier: destroy old + install new on the
    // SAME element. If the destroy runs last, its cleanup strips the styles the
    // new modifier just wrote.
    for (let i = 0; i < 5; i++) {
      state.items = state.items.map((row) => ({ ...row }));
      await settled();
    }

    assert.strictEqual(
      unstyled().length,
      0,
      `every mounted row keeps its absolute translate (lost: ${unstyled().join(", ")})`
    );
  });
});
