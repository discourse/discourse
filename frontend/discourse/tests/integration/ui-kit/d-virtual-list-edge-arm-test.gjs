import { clearRender, render, settled } from "@ember/test-helpers";
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
  return Array.from({ length: count }, (_, id) => ({
    id,
    text: `row ${id}`,
  }));
}

module("Integration | ui-kit | DVirtualList | edge arm", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    enableVirtualization();
  });

  hooks.afterEach(function () {
    disableVirtualization();
  });

  test("edge-arm API retries a failed end fetch without changing items", async function (assert) {
    const items = buildRows(5);
    let api;
    let endFires = 0;
    let fetchAttempts = 0;
    const onRegisterApi = (value) => (api = value);
    const fetchNextPage = async () => {
      fetchAttempts++;
      throw new Error("the page fetch failed");
    };
    const onReachEnd = () => {
      endFires++;
      void fetchNextPage().catch(() => {});
    };

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
          @onReachEnd={{onReachEnd}}
          @overscan={{0}}
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    assert.deepEqual(
      api.visibleRange(),
      { startIndex: 0, endIndex: items.length - 1 },
      "precondition: the whole short list remains in the end band"
    );
    assert.strictEqual(endFires, 1, "the end edge fires once on mount");
    assert.strictEqual(fetchAttempts, 1, "the first edge fire starts a fetch");

    await settled();

    assert.strictEqual(
      endFires,
      1,
      "the failed fetch leaves identical items and does not re-arm automatically"
    );

    api.armEdge("end");

    assert.strictEqual(endFires, 1, "arming does not fire synchronously");

    await settled();

    assert.strictEqual(
      endFires,
      2,
      "the next edge evaluation retries while the range is still in the band"
    );
    assert.strictEqual(fetchAttempts, 2, "the retry starts a second fetch");
  });

  test("edge-arm API re-arms only the requested edge", async function (assert) {
    const items = buildRows(5);
    let api;
    let endFires = 0;
    let startFires = 0;
    const onRegisterApi = (value) => (api = value);
    const onReachEnd = () => endFires++;
    const onReachStart = () => startFires++;

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
          @onReachEnd={{onReachEnd}}
          @onReachStart={{onReachStart}}
          @overscan={{0}}
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    assert.deepEqual(
      api.visibleRange(),
      { startIndex: 0, endIndex: items.length - 1 },
      "precondition: the range overlaps both edge bands"
    );
    assert.strictEqual(endFires, 1, "the end latch is satisfied on mount");
    assert.strictEqual(
      startFires,
      0,
      "the start callback is suppressed on mount"
    );

    api.armEdge("start");

    assert.strictEqual(startFires, 0, "arming does not fire synchronously");

    await settled();

    assert.strictEqual(
      startFires,
      1,
      "the armed start edge fires on evaluation"
    );
    assert.strictEqual(
      endFires,
      1,
      "arming the start edge does not re-arm the end edge"
    );
  });

  test("edge-arm API is safe before initial evaluation and after destruction", async function (assert) {
    const items = buildRows(5);
    let api;
    let endFires = 0;
    const onReachEnd = () => endFires++;
    const onRegisterApi = (value) => {
      api = value;
      api.armEdge("end");
    };

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
          @onReachEnd={{onReachEnd}}
          @overscan={{0}}
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    assert.strictEqual(
      endFires,
      1,
      "arming before the initial evaluation does not duplicate its edge fire"
    );

    await clearRender();

    api.armEdge("start");
    api.armEdge("end");
  });

  test("edge-arm API ignores synchronous self-rearming", async function (assert) {
    const items = buildRows(5);
    let api;
    let endFires = 0;
    const onRegisterApi = (value) => (api = value);
    const onReachEnd = () => {
      endFires++;

      if (endFires < 3) {
        api.armEdge("end");
      }
    };

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
          @onReachEnd={{onReachEnd}}
          @overscan={{0}}
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    assert.deepEqual(
      api.visibleRange(),
      { startIndex: 0, endIndex: items.length - 1 },
      "precondition: the whole short list remains in the end band"
    );

    await settled();

    assert.strictEqual(
      endFires,
      1,
      "synchronously re-arming an executing edge callback is ignored"
    );
  });
});
