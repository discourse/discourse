import { tracked } from "@glimmer/tracking";
import { find, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  disableVirtualization,
  enableVirtualization,
} from "discourse/ui-kit/-internals/windowing/virtualizer";
import DVirtualList from "discourse/ui-kit/d-virtual-list";

const ROW_PX = 40;
const COUNT = 100;

const estimate = () => ROW_PX;
const emptyItems = [];

function buildRows(count) {
  return Array.from({ length: count }, (_, index) => ({
    id: index,
    text: `row ${index}`,
  }));
}

class State {
  @tracked as = "div";
}

function sizerHeight() {
  const sizer = find(".d-virtual-list__sizer");
  return sizer ? parseFloat(sizer.style.height) : null;
}

module("Integration | ui-kit | DVirtualList | container", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    enableVirtualization();
  });

  hooks.afterEach(function () {
    disableVirtualization();
  });

  // `dElement` treats an empty tag name as a pass-through that renders no element
  // at all. The sizer is that element, so an empty `@as` leaves the modifier with
  // nothing to size, no scroll range, and rows resolving their offsets against
  // whatever positioned ancestor happens to exist. Silent, total layout failure.
  test("container fallback: an empty @as still renders a sizer", async function (assert) {
    const items = buildRows(COUNT);
    const blank = "";

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
          @as={{blank}}
          @estimateSize={{estimate}}
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    assert
      .dom(".d-virtual-list__sizer")
      .exists("the sizer element is rendered");
    assert.true(
      sizerHeight() > 0,
      `the sizer carries the engine's height (${sizerHeight()}px)`
    );
  });

  // `@as` is not an argument to the modifier, so changing it swaps the sizer for a
  // fresh element that no flush is scheduled to size. Treating it as mount-time
  // keeps the engine's geometry on an element that cannot be swapped underneath it.
  test("container fallback: changing @as after mount keeps the sized container", async function (assert) {
    const items = buildRows(COUNT);
    const state = new State();

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
          @as={{state.as}}
          @estimateSize={{estimate}}
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    const heightBefore = sizerHeight();
    assert.true(heightBefore > 0, "precondition: the sizer starts sized");

    state.as = "ul";
    await settled();

    assert.true(
      sizerHeight() > 0,
      `the sizer is still sized after @as changes (${sizerHeight()}px)`
    );
  });

  // A roled container has a content model. `listbox` owns options, `list` owns
  // listitems; arbitrary empty-state markup as a direct child is neither, and with
  // `@as="ul"` it is invalid HTML as well.
  test("container fallback: the empty block is not a direct child of the roled container", async function (assert) {
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
          @items={{emptyItems}}
          @as="ul"
          @role="list"
          @estimateSize={{estimate}}
        >
          <:default as |item|><div class="row">{{item.text}}</div></:default>
          <:empty><p class="empty-message">Nothing here yet</p></:empty>
        </DVirtualList>
      </template>
    );

    assert.dom(".empty-message").exists("the empty block renders");
    assert
      .dom(".d-virtual-list__sizer > .empty-message")
      .doesNotExist(
        "the consumer's empty markup is not an owned child of the roled container"
      );
  });

  // The most likely first-run mistake, and silent: the viewport's height belongs to
  // the consumer, and without one the window computes to nothing and the list draws
  // no rows, with no error to explain it.
  test("container fallback: a zero-height viewport warns in development", async function (assert) {
    const items = buildRows(COUNT);
    const warn = sinon.stub(console, "warn");

    await render(
      <template>
        <DVirtualList
          @items={{items}}
          @key="id"
          @estimateSize={{estimate}}
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    assert.true(
      warn.calledWithMatch(/d-virtual-list/i),
      "a zero-height viewport is reported rather than silently rendering nothing"
    );
  });
});
