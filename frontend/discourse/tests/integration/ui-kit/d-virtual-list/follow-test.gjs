import { tracked } from "@glimmer/tracking";
import {
  find,
  render,
  settled,
  triggerEvent,
  waitUntil,
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
const INITIAL_ROWS = 1000;
const APPENDED_ROWS = 10;

// Resting at the end of the initial list: the sizer is 1000 rows tall and the
// viewport shows 400px of it.
const INITIAL_END = INITIAL_ROWS * ROW_PX - VIEWPORT_PX;
// Resting at the end once the appended page has been measured.
const APPENDED_END = (INITIAL_ROWS + APPENDED_ROWS) * ROW_PX - VIEWPORT_PX;

const estimate = () => ROW_PX;

class State {
  @tracked items;

  constructor(items) {
    this.items = items;
  }

  append(count) {
    const from = this.items.length;
    this.items = [
      ...this.items,
      ...Array.from({ length: count }, (_, offset) => ({
        id: from + offset,
        text: `row ${from + offset}`,
      })),
    ];
  }
}

function buildRows(count) {
  return Array.from({ length: count }, (_, index) => ({
    id: index,
    text: `row ${index}`,
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

/**
 * Waits for a scroll to come to rest.
 *
 * Order matters. The Ember commit is what STARTS the engine's reconcile loop, and
 * that loop runs on `requestAnimationFrame`, outside the runloop, so `settled()`
 * does not cover it. Waiting on frames first and settling afterwards is therefore
 * backwards: the trailing settle can kick off the very reconciliation the frames
 * were supposed to await, and the assertion samples an offset still in flight.
 *
 * @param expectedTop When given, the offset to wait for before checking stability.
 */
async function settleScroll(expectedTop) {
  await settled();

  if (expectedTop != null) {
    await waitUntil(() => scroller().scrollTop === expectedTop, {
      timeout: 2000,
    });
  }

  // One stable frame lets the engine observe the position and drop its scroll state.
  await new Promise((resolve) => requestAnimationFrame(resolve));
  await settled();
}

module("Integration | ui-kit | DVirtualList | follow", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    enableVirtualization();
  });

  hooks.afterEach(function () {
    disableVirtualization();
  });

  test("anchor=bottom rests at the end on mount", async function (assert) {
    const state = new State(buildRows(INITIAL_ROWS));

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
          @anchor="bottom"
          @overscan={{0}}
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    await settleScroll(INITIAL_END);

    assert.strictEqual(
      scroller().scrollTop,
      INITIAL_END,
      "the list opens resting at the live edge"
    );
  });

  test("anchor=bottom follows an append while resting at the end", async function (assert) {
    const state = new State(buildRows(INITIAL_ROWS));

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
          @anchor="bottom"
          @overscan={{0}}
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    await settleScroll(INITIAL_END);
    assert.strictEqual(
      scroller().scrollTop,
      INITIAL_END,
      "precondition: resting at the live edge"
    );

    state.append(APPENDED_ROWS);
    await settleScroll(APPENDED_END);

    assert.strictEqual(
      scroller().scrollTop,
      APPENDED_END,
      "the viewport tracks the new live edge after the append"
    );
    assert
      .dom(
        `.d-virtual-list__item[data-index='${INITIAL_ROWS + APPENDED_ROWS - 1}']`
      )
      .exists("the newest row is mounted");
  });

  test("anchor=bottom does not follow an append while scrolled up", async function (assert) {
    const state = new State(buildRows(INITIAL_ROWS));
    const readingAt = 20_000;

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
          @anchor="bottom"
          @overscan={{0}}
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    await settleScroll();
    await scrollTo(readingAt);
    await settleScroll();

    state.append(APPENDED_ROWS);
    await settleScroll();

    assert.strictEqual(
      scroller().scrollTop,
      readingAt,
      "a reader scrolled away from the end is not yanked to the new edge"
    );
  });

  test("scrollEndThreshold widens the band that counts as following", async function (assert) {
    const state = new State(buildRows(INITIAL_ROWS));
    const nearEnd = INITIAL_END - 20;

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
          @anchor="bottom"
          @scrollEndThreshold={{50}}
          @overscan={{0}}
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    await settleScroll();
    await scrollTo(nearEnd);
    await settleScroll();

    state.append(APPENDED_ROWS);
    await settleScroll(APPENDED_END);

    assert.strictEqual(
      scroller().scrollTop,
      APPENDED_END,
      "a reader within the threshold of the end still follows"
    );
  });

  test("without scrollEndThreshold the same near-end offset does not follow", async function (assert) {
    const state = new State(buildRows(INITIAL_ROWS));
    const nearEnd = INITIAL_END - 20;

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
          @anchor="bottom"
          @overscan={{0}}
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    await settleScroll();
    await scrollTo(nearEnd);
    await settleScroll();

    state.append(APPENDED_ROWS);
    await settleScroll();

    assert.strictEqual(
      scroller().scrollTop,
      nearEnd,
      "the engine's 1px default keeps a 20px gap outside the follow band"
    );
  });

  test("a top-anchored list never follows an append", async function (assert) {
    const state = new State(buildRows(INITIAL_ROWS));

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
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    await settleScroll();
    await scrollTo(INITIAL_END);
    await settleScroll();

    state.append(APPENDED_ROWS);
    await settleScroll();

    assert.strictEqual(
      scroller().scrollTop,
      INITIAL_END,
      "omitting @anchor leaves the viewport where the reader left it"
    );
  });
});
