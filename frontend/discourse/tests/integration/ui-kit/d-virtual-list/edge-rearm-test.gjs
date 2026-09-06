import { tracked } from "@glimmer/tracking";
import { find, render, settled, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  disableVirtualization,
  enableVirtualization,
} from "discourse/ui-kit/-internals/windowing/virtualizer";
import DVirtualList from "discourse/ui-kit/d-virtual-list";

const ROW_PX = 40;
const VIEWPORT_PX = 400;

// The default edge threshold is 8 rows and the hysteresis is 4, so an append
// smaller than 13 rows never retreats the range past the re-arm band. A page of
// 10 is the realistic case a paging consumer ships.
const PAGE = 10;

const estimate = () => ROW_PX;

class State {
  @tracked items;

  constructor(items) {
    this.items = items;
  }

  append(count) {
    const from = this.items.length;
    this.items = [...this.items, ...buildRows(count, from)];
  }

  prepend(count) {
    this.items = [...buildRows(count, -count), ...this.items];
  }

  replaceWith(count) {
    this.items = buildRows(count, 10_000);
  }
}

function buildRows(count, from = 0) {
  return Array.from({ length: count }, (_, index) => ({
    id: from + index,
    text: `row ${from + index}`,
  }));
}

function scroller() {
  return find(".d-virtual-list");
}

async function scrollTo(top) {
  const element = scroller();
  element.scrollTop = top;
  await triggerEvent(element, "scroll");
}

module("Integration | ui-kit | DVirtualList | edge re-arm", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    enableVirtualization();
  });

  hooks.afterEach(function () {
    disableVirtualization();
  });

  test("onReachEnd fires again after a page smaller than the hysteresis band", async function (assert) {
    const state = new State(buildRows(100));
    let endFires = 0;
    const onReachEnd = () => endFires++;

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
          @onReachEnd={{onReachEnd}}
          @overscan={{0}}
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    await scrollTo(100 * ROW_PX - VIEWPORT_PX);
    assert.strictEqual(endFires, 1, "precondition: the end edge fired once");

    state.append(PAGE);
    await settled();
    await scrollTo(110 * ROW_PX - VIEWPORT_PX);

    assert.strictEqual(
      endFires,
      2,
      "reaching the new end after a 10-row page fires the end edge again"
    );
  });

  test("an append does not re-arm the start edge", async function (assert) {
    const state = new State(buildRows(100));
    let startFires = 0;
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
          @items={{state.items}}
          @key="id"
          @estimateSize={{estimate}}
          @onReachStart={{onReachStart}}
          @overscan={{0}}
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    assert.strictEqual(
      startFires,
      0,
      "precondition: mount at the top is suppressed"
    );

    state.append(PAGE);
    await settled();

    assert.strictEqual(
      startFires,
      0,
      "a tail-only change must not unlatch the start edge"
    );
  });

  test("a wholesale replacement re-arms the end edge for the new list", async function (assert) {
    const state = new State(buildRows(100));
    let endFires = 0;
    const onReachEnd = () => endFires++;

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
          @onReachEnd={{onReachEnd}}
          @overscan={{0}}
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    await scrollTo(100 * ROW_PX - VIEWPORT_PX);
    assert.strictEqual(endFires, 1, "precondition: the end edge fired once");

    // A short replacement list whose window already reaches its end: the latch
    // from the previous list must not suppress the new list's first fire.
    state.replaceWith(12);
    await settled();

    assert.strictEqual(
      endFires,
      2,
      "a replaced list fires its own end edge rather than inheriting the old latch"
    );
  });

  test("an in-place refresh of the same rows does not re-arm either edge", async function (assert) {
    // No `@key`, so rows key by object identity and a refresh hands both
    // boundaries brand new keys for the very same rows. Re-arming on that turns
    // one edge callback into an endless chain: the consumer answers by
    // refreshing, the boundary key changes, the range is still in the band.
    const state = new State(buildRows(100));
    let endFires = 0;
    let startFires = 0;
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
          @items={{state.items}}
          @estimateSize={{estimate}}
          @onReachEnd={{onReachEnd}}
          @onReachStart={{onReachStart}}
          @overscan={{0}}
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    await scrollTo(100 * ROW_PX - VIEWPORT_PX);
    assert.strictEqual(endFires, 1, "precondition: the end edge fired once");

    // Same length, same logical rows, fresh objects.
    state.items = buildRows(100);
    await settled();

    assert.strictEqual(
      endFires,
      1,
      "a same-length refresh does not re-fire the end edge"
    );
    assert.strictEqual(startFires, 0, "and does not arm the start edge either");
  });

  test("replacing the only row of a single-item list arms nothing", async function (assert) {
    const state = new State(buildRows(1));
    let endFires = 0;
    let startFires = 0;
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
          @items={{state.items}}
          @estimateSize={{estimate}}
          @onReachEnd={{onReachEnd}}
          @onReachStart={{onReachStart}}
          @overscan={{0}}
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    const endAfterMount = endFires;
    state.items = buildRows(1);
    await settled();

    assert.strictEqual(
      endFires,
      endAfterMount,
      "the one row is both boundaries, so replacing it must not fire the end edge"
    );
    assert.strictEqual(startFires, 0, "nor the start edge");
  });

  test("a prepend re-arms the start edge", async function (assert) {
    const state = new State(buildRows(100));
    let startFires = 0;
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
          @items={{state.items}}
          @key="id"
          @estimateSize={{estimate}}
          @onReachStart={{onReachStart}}
          @overscan={{0}}
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    // Move away from the start band so the latch is genuinely re-armed by the
    // head change rather than by a retreat.
    await scrollTo(100 * ROW_PX - VIEWPORT_PX);
    assert.strictEqual(
      startFires,
      0,
      "precondition: never entered the start band"
    );

    state.prepend(PAGE);
    await settled();
    await scrollTo(0);

    assert.strictEqual(
      startFires,
      1,
      "returning to the head of a prepended list fires the start edge"
    );
  });
});
