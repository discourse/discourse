import { tracked } from "@glimmer/tracking";
import { findAll, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  disableVirtualization,
  enableVirtualization,
} from "discourse/ui-kit/-internals/windowing/virtualizer";
import DVirtualList from "discourse/ui-kit/d-virtual-list";

const ROW_PX = 40;
const COUNT = 1000;

function buildRows(count, from = 0) {
  return Array.from({ length: count }, (_, index) => ({
    id: from + index,
    text: `row ${from + index}`,
  }));
}

class State {
  @tracked items = buildRows(COUNT);
  @tracked edgeThreshold = 8;
}

module("Integration | ui-kit | DVirtualList | options reuse", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    enableVirtualization();
  });

  hooks.afterEach(function () {
    disableVirtualization();
  });

  // The engine memoizes its measurements on the identity of the key function among
  // other things. Rebuilding that function on every update busts the memo, so an
  // arg change that moves nothing still walks every index in the list. The cost is
  // proportional to the whole list rather than the window.
  test("options reuse: an unrelated arg change does not re-estimate the whole list", async function (assert) {
    const state = new State();
    let estimateCalls = 0;
    const countingEstimate = () => {
      estimateCalls++;
      return ROW_PX;
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
          @edgeThreshold={{state.edgeThreshold}}
          @estimateSize={{countingEstimate}}
          @items={{state.items}}
          @key="id"
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    assert.true(
      estimateCalls > 0,
      "precondition: the mount estimated the list"
    );
    estimateCalls = 0;

    // Changes nothing about geometry, keys, or the window. It exists only to force
    // the modifier to rebuild its engine options.
    state.edgeThreshold = 4;
    await settled();

    assert.true(
      estimateCalls < COUNT,
      `an arg change that moves nothing re-estimates a window, not the list (${estimateCalls} calls for ${COUNT} rows)`
    );
  });

  // The guard against fixing the above the wrong way. Caching the key function on
  // the item COUNT rather than on the items themselves would survive this suite's
  // happy paths and quietly key a new list by the outgoing list's rows.
  test("options reuse: replacing items with a same-length set still keys the new rows", async function (assert) {
    const state = new State();
    state.items = buildRows(20);
    const estimate = () => ROW_PX;

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
          @estimateSize={{estimate}}
          @items={{state.items}}
          @key="id"
          @overscan={{0}}
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    assert
      .dom(".d-virtual-list__item .row")
      .hasText("row 0", "precondition: the first list is rendered");

    // Same length, entirely different keys.
    state.items = buildRows(20, 500);
    await settled();

    const texts = findAll(".d-virtual-list__item .row").map((row) =>
      row.textContent.trim()
    );

    assert.true(
      texts.every((text) => text.startsWith("row 5")),
      `every mounted row belongs to the incoming list (${texts[0]} … ${texts.at(-1)})`
    );
    assert.strictEqual(
      texts[0],
      "row 500",
      "the window starts at the incoming list's first row"
    );
  });
});
