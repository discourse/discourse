import { find, findAll, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
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

function scroller() {
  return find(".d-virtual-list");
}

function renderedIndices() {
  return findAll(".d-virtual-list__item").map((element) =>
    Number(element.dataset.index)
  );
}

async function renderList(items, onRegisterApi) {
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
        @key="id"
        @estimateSize={{estimate}}
        @onRegisterApi={{onRegisterApi}}
        @overscan={{0}}
        as |item|
      >
        <div class="row" style="height: 40px">{{item.text}}</div>
      </DVirtualList>
    </template>
  );
}

module("Integration | ui-kit | DVirtualList | API surface", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    enableVirtualization();
  });

  hooks.afterEach(function () {
    disableVirtualization();
  });

  test("API surface pin: visibleRange is undefined before an empty list is measured", async function (assert) {
    let api;
    const onRegisterApi = (value) => (api = value);

    await renderList([], onRegisterApi);

    assert.strictEqual(
      api.visibleRange(),
      undefined,
      "an empty list has no visible range before measurement"
    );
  });

  for (const [label, dataIndex] of [
    ["an empty data-index", ""],
    ["a malformed data-index", "not-an-index"],
    ["an out-of-range data-index", "100"],
  ]) {
    test(`API surface pin: measureElement ignores ${label}`, async function (assert) {
      const items = buildRows(100);
      let api;
      const onRegisterApi = (value) => (api = value);

      await renderList(items, onRegisterApi);

      const rangeBeforeMeasurement = { ...api.visibleRange() };
      const windowBeforeMeasurement = renderedIndices();
      const warn = sinon.stub(console, "warn");
      const foreignElement = document.createElement("div");
      foreignElement.dataset.index = dataIndex;
      foreignElement.style.height = `${ROW_PX * 2}px`;
      scroller().append(foreignElement);
      let thrown;

      try {
        api.measureElement(foreignElement);
      } catch (error) {
        thrown = error;
      }
      await settled();

      assert.strictEqual(thrown, undefined, `${label} does not throw`);
      assert.false(
        warn.called,
        `${label} is rejected without an engine warning`
      );
      assert.deepEqual(
        api.visibleRange(),
        rangeBeforeMeasurement,
        `${label} does not disturb the visible range`
      );
      assert.deepEqual(
        renderedIndices(),
        windowBeforeMeasurement,
        `${label} does not disturb the rendered window`
      );
    });
  }

  test("API surface pin: measureElement ignores an untyped non-HTMLElement", async function (assert) {
    const items = buildRows(100);
    let api;
    const onRegisterApi = (value) => (api = value);

    await renderList(items, onRegisterApi);

    const rangeBeforeMeasurement = { ...api.visibleRange() };
    const windowBeforeMeasurement = renderedIndices();
    const warn = sinon.stub(console, "warn");
    let thrown;

    try {
      api.measureElement({});
    } catch (error) {
      thrown = error;
    }
    await settled();

    assert.strictEqual(
      thrown,
      undefined,
      "an untyped non-HTMLElement does not throw"
    );
    assert.false(
      warn.called,
      "an untyped non-HTMLElement is rejected without an engine warning"
    );
    assert.deepEqual(
      api.visibleRange(),
      rangeBeforeMeasurement,
      "an untyped non-HTMLElement does not disturb the visible range"
    );
    assert.deepEqual(
      renderedIndices(),
      windowBeforeMeasurement,
      "an untyped non-HTMLElement does not disturb the rendered window"
    );
  });

  test("API surface pin: measureElement forwards an unregistered valid row", async function (assert) {
    const items = buildRows(100);
    let api;
    const onRegisterApi = (value) => (api = value);

    await renderList(items, onRegisterApi);

    const unregisteredIndex = api.visibleRange().endIndex + 1;
    const totalBeforeMeasurement = parseFloat(
      find(".d-virtual-list__sizer").style.height
    );
    const unregisteredRow = document.createElement("div");
    unregisteredRow.dataset.index = String(unregisteredIndex);
    unregisteredRow.style.height = `${ROW_PX * 2}px`;
    scroller().append(unregisteredRow);

    assert.false(
      renderedIndices().includes(unregisteredIndex),
      "precondition: the valid row was not registered by the row modifier"
    );

    api.measureElement(unregisteredRow);
    await settled();

    assert.strictEqual(
      parseFloat(find(".d-virtual-list__sizer").style.height),
      totalBeforeMeasurement + ROW_PX,
      "the public method forwards the row's measured growth to the engine"
    );
  });

  test("API surface pin: visibleRange is an immutable snapshot", async function (assert) {
    const items = buildRows(100);
    let api;
    const onRegisterApi = (value) => (api = value);

    await renderList(items, onRegisterApi);

    const exposedRange = api.visibleRange();
    const rangeBeforeMutation = { ...exposedRange };
    const windowBeforeMutation = renderedIndices();
    const replacementStart = exposedRange.endIndex + 1;

    assert.true(
      Object.isFrozen(exposedRange),
      "the public range object is frozen"
    );
    assert.throws(
      () => (exposedRange.startIndex = replacementStart),
      TypeError,
      "attempting to mutate the range is rejected"
    );
    assert.deepEqual(
      renderedIndices(),
      windowBeforeMutation,
      "the mutation attempt does not change the rendered window"
    );
    assert.deepEqual(
      api.visibleRange(),
      rangeBeforeMutation,
      "a later range read retains the committed indices"
    );
  });

  test("API surface pin: measureElement ignores an element without data-index", async function (assert) {
    const items = buildRows(100);
    let api;
    const onRegisterApi = (value) => (api = value);

    await renderList(items, onRegisterApi);

    const rangeBeforeMeasurement = { ...api.visibleRange() };
    const windowBeforeMeasurement = renderedIndices();
    const warn = sinon.stub(console, "warn");
    const foreignElement = document.createElement("div");
    foreignElement.style.position = "absolute";
    foreignElement.style.height = `${ROW_PX * 2}px`;
    scroller().append(foreignElement);

    api.measureElement(foreignElement);
    await settled();

    assert.false(
      warn.called,
      "an unindexed element is rejected before reaching the engine"
    );
    assert.deepEqual(
      api.visibleRange(),
      rangeBeforeMeasurement,
      "the foreign element does not disturb the visible range"
    );
    assert.deepEqual(
      renderedIndices(),
      windowBeforeMeasurement,
      "the foreign element does not disturb the rendered window"
    );

    const measuredRow = find(".d-virtual-list__item");
    const rowContent = measuredRow.querySelector(".row");
    const heightBeforeResize = measuredRow.offsetHeight;
    const totalBeforeResize = parseFloat(
      find(".d-virtual-list__sizer").style.height
    );
    const resizeDelivered = new Promise((resolve) => {
      const observer = new ResizeObserver(() => {
        observer.disconnect();
        resolve();
      });
      observer.observe(measuredRow, { box: "border-box" });
    });
    rowContent.style.height = `${heightBeforeResize + ROW_PX / 2}px`;
    await resizeDelivered;
    await settled();

    const measuredGrowth = measuredRow.offsetHeight - heightBeforeResize;
    assert.strictEqual(
      parseFloat(find(".d-virtual-list__sizer").style.height),
      totalBeforeResize + measuredGrowth,
      "a real row still updates the measurement cache afterwards"
    );
  });

  test("API surface pin: scrollToOffset moves the rendered window", async function (assert) {
    const items = buildRows(100);
    let api;
    const onRegisterApi = (value) => (api = value);

    await renderList(items, onRegisterApi);

    const measuredRowHeight = find(".d-virtual-list__item").offsetHeight;
    const targetIndex = api.visibleRange().endIndex + 5;
    const targetOffset = targetIndex * measuredRowHeight;

    api.scrollToOffset(targetOffset);
    await settled();

    assert.strictEqual(
      scroller().scrollTop,
      targetOffset,
      "the viewport moves to the requested measured offset"
    );
    assert.strictEqual(
      api.visibleRange().startIndex,
      targetIndex,
      "the visible range starts with the row at that offset"
    );
    assert.true(
      renderedIndices().includes(targetIndex),
      "the row at the requested offset is mounted"
    );
  });

  test("API surface pin: scrollToEdge start returns a scrolled list to the top", async function (assert) {
    const items = buildRows(100);
    let api;
    const onRegisterApi = (value) => (api = value);

    await renderList(items, onRegisterApi);

    api.scrollToEdge("end");
    await settled();

    assert.true(
      api.visibleRange().startIndex > 0,
      "precondition: the list is scrolled away from the start"
    );

    api.scrollToEdge("start");
    await settled();

    assert.strictEqual(scroller().scrollTop, 0, "the viewport returns to zero");
    assert.strictEqual(
      api.visibleRange().startIndex,
      0,
      "the visible range returns to the first row"
    );
    assert.true(
      renderedIndices().includes(0),
      "the first row is mounted again"
    );
  });

  test("API surface pin: remeasureViewport immediately adopts a new height", async function (assert) {
    const items = buildRows(100);
    let api;
    const onRegisterApi = (value) => (api = value);

    await renderList(items, onRegisterApi);

    const viewport = scroller();
    const measuredRowHeight = find(".d-virtual-list__item").offsetHeight;
    const newViewportHeight = viewport.offsetHeight + measuredRowHeight * 3;
    viewport.style.height = `${newViewportHeight}px`;

    assert.strictEqual(
      viewport.offsetHeight,
      newViewportHeight,
      "precondition: layout exposes the new viewport height"
    );

    api.remeasureViewport();
    await settled();

    const expectedVisibleRows = Math.ceil(
      newViewportHeight / measuredRowHeight
    );
    assert.strictEqual(
      api.visibleRange().endIndex - api.visibleRange().startIndex + 1,
      expectedVisibleRows,
      "the visible range uses the new viewport height"
    );
    assert.strictEqual(
      renderedIndices().length,
      expectedVisibleRows,
      "the list mounts exactly the rows implied by the new height"
    );
  });

  test("API surface pin: isScrolling is false at rest", async function (assert) {
    const items = buildRows(100);
    let api;
    const onRegisterApi = (value) => (api = value);

    await renderList(items, onRegisterApi);

    assert.strictEqual(
      typeof api.isScrolling,
      "boolean",
      "isScrolling exposes a boolean"
    );
    assert.false(api.isScrolling, "the list reports that it is idle at rest");
  });

  test("API surface pin: scrollToEdge is inert for an empty list", async function (assert) {
    const items = [];
    let api;
    const onRegisterApi = (value) => (api = value);

    await renderList(items, onRegisterApi);

    const scrollTopBefore = scroller().scrollTop;
    api.scrollToEdge("start");
    api.scrollToEdge("end");

    assert.strictEqual(
      scroller().scrollTop,
      scrollTopBefore,
      "both edge requests remain harmless no-ops"
    );
  });
});
