import { find, render, settled, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DVirtualList from "discourse/ui-kit/d-virtual-list";
import {
  disableVirtualization,
  enableVirtualization,
} from "discourse/ui-kit/lib/virtualizer";

const ROW_PX = 40;
const estimate = () => ROW_PX;

function buildRows(count) {
  return Array.from({ length: count }, (_, index) => ({
    id: index,
    text: `row ${index}`,
  }));
}

async function scrollTo(top) {
  const element = find(".d-virtual-list");
  element.scrollTop = top;
  await triggerEvent(element, "scroll");
}

module("Integration | ui-kit | DVirtualList | edges", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    enableVirtualization();
  });

  hooks.afterEach(function () {
    disableVirtualization();
  });

  test("visible-range changes ignore size-only remeasurement", async function (assert) {
    const items = buildRows(100);
    const ranges = [];
    let api;
    const onRegisterApi = (value) => (api = value);
    const onVisibleRangeChange = (range) => ranges.push({ ...range });

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
          @items={{items}}
          @estimateSize={{estimate}}
          @onRegisterApi={{onRegisterApi}}
          @onVisibleRangeChange={{onVisibleRangeChange}}
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    await scrollTo(ROW_PX * 20 + 10);

    const countBeforeResize = ranges.length;
    const rangeBeforeResize = api.visibleRange();
    const measuredRow = find(
      `.d-virtual-list__item[data-index='${rangeBeforeResize.startIndex + 2}']`
    );
    const resizeDelivered = new Promise((resolve) => {
      const observer = new ResizeObserver(() => {
        if (measuredRow.offsetHeight === 41) {
          observer.disconnect();
          resolve();
        }
      });
      observer.observe(measuredRow, { box: "border-box" });
    });
    measuredRow.querySelector(".row").style.height = "41px";
    await resizeDelivered;
    await settled();

    assert.deepEqual(
      api.visibleRange(),
      rangeBeforeResize,
      "the resize leaves the visible start and end indices unchanged"
    );
    assert.strictEqual(
      ranges.length,
      countBeforeResize,
      "a size-only remeasurement does not publish a visible-range change"
    );

    const countBeforeScroll = ranges.length;
    await scrollTo(ROW_PX * 30 + 10);

    assert.strictEqual(
      ranges.length,
      countBeforeScroll + 1,
      "a scroll that changes the visible indices publishes once"
    );
  });

  test("end edge fires once per entry and re-arms after retreat", async function (assert) {
    const items = buildRows(100);
    const calls = [];
    let api;
    const onRegisterApi = (value) => (api = value);
    const onReachEnd = (range) => calls.push(range);

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
          @items={{items}}
          @estimateSize={{estimate}}
          @onRegisterApi={{onRegisterApi}}
          @onReachEnd={{onReachEnd}}
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    await scrollTo(ROW_PX * 81);
    assert.strictEqual(
      calls.length,
      0,
      "the default threshold waits until the last eight rows"
    );

    await scrollTo(ROW_PX * 82);

    assert.strictEqual(calls.length, 1, "entering the end band fires once");
    assert.deepEqual(
      calls[0],
      { ...api.visibleRange(), count: items.length },
      "the callback receives the visible range and item count"
    );

    await scrollTo(ROW_PX * 82 + 20);
    assert.strictEqual(
      calls.length,
      1,
      "continued scrolling within the end band does not re-fire"
    );

    await scrollTo(ROW_PX * 60);
    await scrollTo(ROW_PX * 82);

    assert.strictEqual(
      calls.length,
      2,
      "retreating beyond hysteresis re-arms the end edge"
    );
  });

  test("start edge suppresses mount and fires after leaving and returning", async function (assert) {
    const items = buildRows(100);
    const calls = [];
    let api;
    const onRegisterApi = (value) => (api = value);
    const onReachStart = (range) => calls.push(range);

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
          @items={{items}}
          @estimateSize={{estimate}}
          @onRegisterApi={{onRegisterApi}}
          @onReachStart={{onReachStart}}
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    assert.strictEqual(
      calls.length,
      0,
      "initial mount at offset zero is suppressed"
    );

    await scrollTo(ROW_PX * items.length);
    await scrollTo(0);

    assert.strictEqual(
      calls.length,
      1,
      "returning to the start band fires once"
    );
    assert.deepEqual(
      calls[0],
      { ...api.visibleRange(), count: items.length },
      "the callback receives the visible range and item count"
    );
  });

  test("end edge fires on mount when the whole list fits", async function (assert) {
    const items = buildRows(5);
    const calls = [];
    const onReachEnd = (range) => calls.push(range);

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
          @items={{items}}
          @estimateSize={{estimate}}
          @onReachEnd={{onReachEnd}}
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    assert.strictEqual(
      calls.length,
      1,
      "a fully visible list reaches the end on mount"
    );
    assert.deepEqual(
      calls[0],
      { startIndex: 0, endIndex: 4, count: 5 },
      "the initial-fill callback describes the complete list"
    );
  });
});
