import { tracked } from "@glimmer/tracking";
import {
  find,
  findAll,
  render,
  settled,
  triggerEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DVirtualList from "discourse/ui-kit/d-virtual-list";
import {
  disableVirtualization,
  enableVirtualization,
} from "discourse/ui-kit/lib/virtualizer";

const ROW_PX = 40;
const VIEWPORT_PX = 400;

const estimate = () => ROW_PX;

class State {
  @tracked items;

  constructor(items) {
    this.items = items;
  }

  prepend(count) {
    this.items = [...buildRows(count, -count), ...this.items];
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

function renderedIndices() {
  return findAll(".d-virtual-list__item").map((element) =>
    Number(element.dataset.index)
  );
}

async function scrollTo(top) {
  const element = scroller();
  element.scrollTop = top;
  await triggerEvent(element, "scroll");
}

module("Integration | ui-kit | DVirtualList | resilience", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    enableVirtualization();
    // These tests drive consumer callbacks that throw on purpose; the primitive
    // reports them rather than rethrowing, so silence the report itself.
    sinon.stub(console, "error");
  });

  hooks.afterEach(function () {
    disableVirtualization();
  });

  test("a throwing onReachEnd still leaves the window published", async function (assert) {
    // Short enough that the end band is reached on mount, which is when a
    // throwing callback would abort the very first publish.
    const items = buildRows(12);
    const explode = () => {
      throw new Error("consumer blew up");
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
          @onReachEnd={{explode}}
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    assert.true(
      renderedIndices().length > 0,
      "rows still render after the edge callback threw"
    );
    assert.true(
      find(".d-virtual-list__sizer").offsetHeight > 0,
      "the sizer still took the list's height"
    );
  });

  test("a throwing pinnedIndices degrades to the unextended window", async function (assert) {
    const items = buildRows(100);
    const explode = () => {
      throw new Error("pins blew up");
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
          @pinnedIndices={{explode}}
          @overscan={{0}}
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    await scrollTo(100 * ROW_PX - VIEWPORT_PX);

    const indices = renderedIndices();
    assert.true(
      indices.length > 0,
      "the list keeps rendering its default window"
    );
    assert.false(
      indices.includes(0),
      "no pin is applied, rather than the render crashing on a poisoned window"
    );
  });

  test("a shrink never yields a row without a backing item", async function (assert) {
    // Mirrors the pass in which `@items` has shrunk but the window published by
    // the after-render flush still describes the previous, longer list.
    const state = new State(buildRows(100));
    const seen = [];
    const record = (item) => {
      seen.push(item);
      return "";
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
          @items={{state.items}}
          @key="id"
          @estimateSize={{estimate}}
          @overscan={{0}}
          as |item|
        >
          <div class="row" style="height: 40px">{{record item}}</div>
        </DVirtualList>
      </template>
    );

    await scrollTo(100 * ROW_PX - VIEWPORT_PX);
    seen.length = 0;

    state.items = buildRows(3);
    await settled();

    assert.true(
      seen.length > 0,
      "precondition: rows re-rendered on the shrink"
    );
    assert.true(
      seen.every((item) => item != null),
      "every yielded row had a real item behind it"
    );
  });

  test("prepending more than the remaining scroll distance holds the reader's row", async function (assert) {
    const state = new State(buildRows(30));

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

    // Rest at the top: the whole list is 1200px against a 400px viewport, so a
    // 30-row prepend is far taller than the 800px left below the reader. That
    // is what makes the engine's anchored offset unreachable under the old
    // sizer height, which is the condition the anchor has to survive.
    await scrollTo(0);
    const anchorIndex = renderedIndices()[0];

    state.prepend(30);
    await settled();

    assert.strictEqual(
      scroller().scrollTop,
      30 * ROW_PX,
      "the viewport moved down by exactly the height that arrived above it"
    );
    assert.true(
      renderedIndices().includes(anchorIndex + 30),
      "the row the reader was looking at is still the one in view"
    );
  });
});
