// Disabling virtualization must leave the render-all fallback active while making
// every virtualizer callback inert.
import { tracked } from "@glimmer/tracking";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DVirtualList from "discourse/ui-kit/d-virtual-list";
import {
  disableVirtualization,
  enableVirtualization,
} from "discourse/ui-kit/lib/virtualizer";

const estimateSize = () => 40;

class State {
  @tracked items;

  constructor(items) {
    this.items = items;
  }
}

function buildRows(count) {
  return Array.from({ length: count }, (_, id) => ({
    id,
    text: `row ${id}`,
  }));
}

module("Integration | ui-kit | DVirtualList | inert", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    enableVirtualization();
  });

  test("disabled virtualization renders all rows without invoking callbacks", async function (assert) {
    disableVirtualization();

    const state = new State(buildRows(5));
    const calls = {
      registerApi: 0,
      reachEnd: 0,
      reachStart: 0,
      visibleRangeChange: 0,
    };
    const onRegisterApi = () => calls.registerApi++;
    const onReachEnd = () => calls.reachEnd++;
    const onReachStart = () => calls.reachStart++;
    const onVisibleRangeChange = () => calls.visibleRangeChange++;

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
          @estimateSize={{estimateSize}}
          @onRegisterApi={{onRegisterApi}}
          @onVisibleRangeChange={{onVisibleRangeChange}}
          @onReachStart={{onReachStart}}
          @onReachEnd={{onReachEnd}}
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    state.items = state.items.map((item) => ({
      ...item,
      text: `${item.text} replaced`,
    }));
    await settled();

    assert.dom(".row").exists({ count: 5 }, "renders every fallback row");
    assert.strictEqual(
      calls.visibleRangeChange,
      0,
      "does not publish a visible range"
    );
    assert.strictEqual(calls.reachEnd, 0, "does not report the end edge");
    assert.strictEqual(calls.reachStart, 0, "does not report the start edge");
    assert.strictEqual(calls.registerApi, 0, "does not register an API");
  });
});
