import { tracked } from "@glimmer/tracking";
import { find, render, settled, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  disableVirtualization,
  enableVirtualization,
} from "discourse/ui-kit/-internals/windowing/virtualizer";
import DVirtualList from "discourse/ui-kit/d-virtual-list";
import dVirtualizer from "discourse/ui-kit/modifiers/d-virtualizer";

const ROW_PX = 40;
const VIEWPORT_PX = 400;
const estimate = () => ROW_PX;

function buildRows(count) {
  return Array.from({ length: count }, (_, index) => ({
    id: index,
    text: `row ${index}`,
  }));
}

class State {
  @tracked items = buildRows(100);
  @tracked estimate = estimate;
  @tracked edgeThreshold = 8;
}

async function scrollTo(top) {
  const element = find(".d-virtual-list");
  element.scrollTop = top;
  await triggerEvent(element, "scroll");
}

module("Integration | ui-kit | DVirtualList | lifecycle", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    enableVirtualization();
  });

  hooks.afterEach(function () {
    disableVirtualization();
  });

  // Emptying a list mid-scroll takes two engine-live branches nothing else
  // reaches: the sizer's height is dropped entirely, and the edge latches plus
  // the remembered boundary keys return to their mount state, so a refill can
  // fire its end edge again.
  test("lifecycle pin: emptying and refilling a list clears its height and re-arms its edges", async function (assert) {
    const state = new State();
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
          @overscan={{0}}
          @onReachEnd={{onReachEnd}}
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    await scrollTo(100 * ROW_PX - VIEWPORT_PX);
    assert.true(
      endFires > 0,
      "precondition: the end edge fired while populated"
    );
    const firesWhilePopulated = endFires;

    state.items = [];
    await settled();

    assert.dom(".d-virtual-list__item").doesNotExist("no rows remain");
    assert.strictEqual(
      find(".d-virtual-list__sizer").style.height,
      "",
      "the sizer drops its height rather than keeping the outgoing list's scroll range"
    );

    state.items = buildRows(12);
    await settled();

    assert.true(
      endFires > firesWhilePopulated,
      "the refilled list can fire its end edge again"
    );
  });

  // NOT COVERED: the mount-rollback invariant (a mount whose `@estimateSize` throws
  // must not be adopted, so a later update re-enters the mount branch and still
  // registers the api). A test for it is possible to write but not to ship: the
  // throw escapes from the after-render flush rather than from `render()`, so it
  // cannot be caught at the call site and surfaces as a global error that aborts
  // the rest of the suite. Pinning it needs a way to scope a global-error handler
  // to one test, which this suite does not have today.

  // The window memo is committed before the publish runs. If the publish throws,
  // the memo has to be dropped: keeping it would match every later identical
  // window and strand a mounted list on whatever it last drew.
  test("lifecycle pin: a publish that throws does not strand the window", async function (assert) {
    const state = new State();
    const payloads = [];
    let shouldThrow = true;
    const onState = (payload) => {
      if (shouldThrow) {
        shouldThrow = false;
        throw new Error("onState failed");
      }
      payloads.push(payload);
    };

    await render(
      <template>
        <div
          class="viewport"
          style="height: 400px; overflow-y: auto"
          {{dVirtualizer
            items=state.items
            estimateSize=estimate
            key="id"
            edgeThreshold=state.edgeThreshold
            onState=onState
          }}
        >
          <div class="d-virtual-list__sizer"></div>
        </div>
      </template>
    );

    assert.strictEqual(
      payloads.length,
      0,
      "precondition: the first publish threw and delivered nothing"
    );

    // Re-run the modifier without moving the window, so the republish depends on
    // the failed memo having been dropped rather than on the signature changing.
    state.edgeThreshold = 4;
    await settled();

    assert.true(
      payloads.length > 0,
      "a later flush publishes the window despite the identical signature"
    );
    assert.true(
      payloads.at(-1).virtualItems.length > 0,
      "the recovered publish carries a real window"
    );
  });

  // `@setSize` exists for a windowed view onto an unbounded stream, where the
  // backing array length is not the real total and -1 means indeterminable.
  test("lifecycle pin: an explicit setSize overrides the item count", async function (assert) {
    const items = buildRows(3);
    const unbounded = -1;

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
          @role="listbox"
          @itemRole="option"
          @setSize={{unbounded}}
          as |item|
        >
          <span>{{item.text}}</span>
        </DVirtualList>
      </template>
    );

    assert
      .dom(".d-virtual-list__item")
      .hasAttribute(
        "aria-setsize",
        "-1",
        "the consumer's declared total wins over the backing array length"
      );
  });

  test("lifecycle pin: setSize is omitted for a role that does not define it", async function (assert) {
    const items = buildRows(3);
    const unbounded = -1;

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
          @setSize={{unbounded}}
          as |item|
        >
          <span>{{item.text}}</span>
        </DVirtualList>
      </template>
    );

    assert
      .dom(".d-virtual-list__item")
      .doesNotHaveAttribute(
        "aria-setsize",
        "a row with no position-aware role carries no set size"
      );
  });
});
