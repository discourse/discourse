import { find, render, resetOnerror, setupOnerror } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DVirtualList from "discourse/ui-kit/d-virtual-list";
import {
  disableVirtualization,
  enableVirtualization,
} from "discourse/ui-kit/lib/virtualizer";

const ROW_PX = 40;
const INITIAL_INDEX = 100;
const estimate = () => ROW_PX;

function buildRows(count) {
  return Array.from({ length: count }, (_, index) => ({
    id: index,
    text: `row ${index}`,
  }));
}

module("Integration | ui-kit | DVirtualList | mount order", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    enableVirtualization();
  });

  hooks.afterEach(function () {
    resetOnerror();
    disableVirtualization();
  });

  // The list's own mount positioning must not depend on consumer code
  // succeeding. `@onRegisterApi` hands out a handle, and a consumer is free to
  // do something that throws with it.
  test("a throwing @onRegisterApi still leaves the list at @initialIndex", async function (assert) {
    const items = buildRows(300);
    const caught = [];
    setupOnerror((error) => caught.push(error));

    const onRegisterApi = () => {
      throw new Error("consumer boom");
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
          @initialIndex={{INITIAL_INDEX}}
          @onRegisterApi={{onRegisterApi}}
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    assert.strictEqual(
      caught.length,
      1,
      "the consumer's throw surfaces rather than being swallowed"
    );
    assert.strictEqual(
      find(".d-virtual-list").scrollTop,
      INITIAL_INDEX * ROW_PX,
      "and the list still opens at the requested index"
    );
  });

  test("@initialIndex is applied when the consumer callback succeeds", async function (assert) {
    const items = buildRows(300);
    let handle;
    const onRegisterApi = (api) => (handle = api);

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
          @initialIndex={{INITIAL_INDEX}}
          @onRegisterApi={{onRegisterApi}}
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    assert.strictEqual(
      typeof handle?.scrollToIndex,
      "function",
      "the consumer receives a usable API handle"
    );
    assert.strictEqual(
      find(".d-virtual-list").scrollTop,
      INITIAL_INDEX * ROW_PX,
      "and the list opens at the requested index"
    );
  });
});
