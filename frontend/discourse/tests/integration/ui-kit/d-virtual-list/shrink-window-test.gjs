import { tracked } from "@glimmer/tracking";
import {
  find,
  findAll,
  render,
  settled,
  triggerEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  disableVirtualization,
  enableVirtualization,
} from "discourse/ui-kit/-internals/windowing/virtualizer";
import DVirtualList from "discourse/ui-kit/d-virtual-list";

const ROW_PX = 40;
const VIEWPORT_PX = 400;
const LONG_COUNT = 100;
const SHORT_COUNT = 10;

const estimate = () => ROW_PX;

class State {
  @tracked items;

  constructor(items) {
    this.items = items;
  }
}

/**
 * Ids start at `from` so a shrink can hand over rows the outgoing list never
 * contained. The engine resolves its scroll anchor by key, so reusing ids would
 * let it find the anchor and correct the offset on its own, hiding the defect.
 */
function buildRows(count, from = 0) {
  return Array.from({ length: count }, (_, index) => ({
    id: from + index,
    text: `row ${from + index}`,
  }));
}

async function scrollTo(top) {
  const element = find(".d-virtual-list");
  element.scrollTop = top;
  await triggerEvent(element, "scroll");
}

module("Integration | ui-kit | DVirtualList | shrink window", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    enableVirtualization();
  });

  hooks.afterEach(function () {
    disableVirtualization();
  });

  test("a deep shrink never publishes a window past the new end", async function (assert) {
    // The flush reads the window from the engine before it settles the sizer to
    // the shrunk total. Until that height lands the browser has not clamped
    // `scrollTop`, so the engine still answers from the outgoing list's offset
    // and the published range collapses onto the last row of the new list.
    const state = new State(buildRows(LONG_COUNT));
    const ranges = [];
    // Recorded as strings so a failure names the offending window rather than
    // printing `[object Object]`.
    const onVisibleRangeChange = (range) =>
      ranges.push(`${range.startIndex}-${range.endIndex}`);

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
          @overscan={{0}}
          @onVisibleRangeChange={{onVisibleRangeChange}}
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    await scrollTo(LONG_COUNT * ROW_PX - VIEWPORT_PX);

    assert.true(
      ranges.length > 0,
      "precondition: scrolling to the end published a range"
    );

    // Drop the pre-shrink windows. Those legitimately sit at the end of the long
    // list; only what is published from the shrink onwards is under test.
    ranges.length = 0;

    state.items = buildRows(SHORT_COUNT, 1000);
    await settled();

    assert.true(
      ranges.length > 0,
      "precondition: the shrink published at least one range"
    );

    // The whole shrunk list fits the viewport, so every window it can legitimately
    // occupy starts at row 0. One that starts later was computed against the
    // outgoing list's scroll offset.
    assert.deepEqual(
      ranges.filter((range) => !range.startsWith("0-")),
      [],
      "no window published from the shrink starts past the first row of a list that fits the viewport"
    );
  });

  test("a deep shrink publishes a window covering the whole shorter list", async function (assert) {
    // The positive half. This one can also pass on the defective ordering once
    // the browser's clamp fires its scroll event and a corrected flush lands, so
    // it guards the settled result rather than discriminating the bug.
    const state = new State(buildRows(LONG_COUNT));
    const ranges = [];
    const onVisibleRangeChange = (range) =>
      ranges.push(`${range.startIndex}-${range.endIndex}`);

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
          @overscan={{0}}
          @onVisibleRangeChange={{onVisibleRangeChange}}
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    await scrollTo(LONG_COUNT * ROW_PX - VIEWPORT_PX);

    state.items = buildRows(SHORT_COUNT, 1000);
    await settled();

    assert.strictEqual(
      ranges.at(-1),
      `0-${SHORT_COUNT - 1}`,
      "the last published range spans the shrunk list"
    );
    assert.strictEqual(
      findAll(".d-virtual-list__item").length,
      SHORT_COUNT,
      "every row of the shrunk list is mounted"
    );
  });
});
