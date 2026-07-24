import { tracked } from "@glimmer/tracking";
import {
  find,
  findAll,
  render,
  settled,
  triggerEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DVirtualList from "discourse/ui-kit/d-virtual-list";
import {
  disableVirtualization,
  enableVirtualization,
} from "discourse/ui-kit/lib/virtualizer";

const ROW_PX = 40;
const estimate = () => ROW_PX;

class State {
  @tracked items;

  constructor(items) {
    this.items = items;
  }
}

function buildRows(count) {
  return Array.from({ length: count }, (_, index) => ({
    id: index,
    text: `row ${index}`,
  }));
}

async function scrollTo(top) {
  const element = find(".d-virtual-list");
  element.scrollTop = top;
  await triggerEvent(element, "scroll");
}

function renderedIndices() {
  return findAll(".d-virtual-list__item").map((element) =>
    Number(element.dataset.index)
  );
}

function renderedPositions() {
  return findAll(".d-virtual-list__item").map((element) =>
    Number(element.getAttribute("aria-posinset"))
  );
}

function isStrictlyAscending(values) {
  return values.every(
    (value, index) => index === 0 || values[index - 1] < value
  );
}

module("Integration | ui-kit | DVirtualList | anchoring", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    enableVirtualization();
  });

  hooks.afterEach(function () {
    disableVirtualization();
  });

  test("initialIndex defaults to start alignment", async function (assert) {
    const items = buildRows(1000);

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
          @estimateSize={{estimate}}
          @initialIndex={{500}}
          @overscan={{0}}
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    assert.strictEqual(
      renderedIndices()[0],
      500,
      "the initial index is the first rendered row"
    );
  });

  for (const [align, expectedScrollTop] of [
    ["start", 20_000],
    ["center", 19_820],
    ["end", 19_640],
    ["auto", 19_640],
  ]) {
    test(`initialAlign=${align} positions the initial row`, async function (assert) {
      const items = buildRows(1000);

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
            @estimateSize={{estimate}}
            @initialIndex={{500}}
            @initialAlign={{align}}
            @overscan={{0}}
            as |item|
          >
            <div class="row" style="height: 40px">{{item.text}}</div>
          </DVirtualList>
        </template>
      );

      assert.strictEqual(
        find(".d-virtual-list").scrollTop,
        expectedScrollTop,
        `row 500 uses ${align} alignment in the 400px viewport`
      );
    });
  }

  test("initial positioning runs only once", async function (assert) {
    const state = new State(buildRows(1000));

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
          @initialIndex={{500}}
          @overscan={{0}}
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    assert.strictEqual(
      renderedIndices()[0],
      500,
      "the initial positioning starts the window at row 500"
    );

    await scrollTo(0);
    state.items = buildRows(1000);
    await settled();

    assert
      .dom(".d-virtual-list__item[data-index='0']")
      .exists("a fresh item array leaves the user at the top");
    assert
      .dom(".d-virtual-list__item[data-index='500']")
      .doesNotExist(
        "a fresh item array does not re-apply the initial position"
      );
  });

  test("an off-window pinned row stays mounted in ascending DOM order", async function (assert) {
    const items = buildRows(100);

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
          @itemRole="option"
          @pinnedIndex={{0}}
          @overscan={{0}}
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    await scrollTo(ROW_PX * 100);

    const indices = renderedIndices();
    const positions = renderedPositions();

    assert
      .dom(".d-virtual-list__item[data-index='0']")
      .exists("the pinned row remains mounted outside the visible window");
    assert.strictEqual(
      indices[0],
      0,
      "the pinned row precedes the bottom window in DOM order"
    );
    assert.true(
      isStrictlyAscending(indices),
      `rendered data-index values are strictly ascending (${indices.join(", ")})`
    );
    assert.true(
      isStrictlyAscending(positions),
      `rendered aria-posinset values are strictly ascending (${positions.join(", ")})`
    );
  });

  test("a pinned row inside the visible window is not duplicated", async function (assert) {
    const items = buildRows(100);

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
          @pinnedIndex={{5}}
          @overscan={{0}}
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    assert
      .dom(".d-virtual-list__item[data-index='5']")
      .exists(
        { count: 1 },
        "the visible pinned row has exactly one DOM instance"
      );
  });

  test("a null pinnedIndex renders no extra off-window row", async function (assert) {
    const items = buildRows(100);

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
          @pinnedIndex={{null}}
          @overscan={{0}}
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    await scrollTo(ROW_PX * 100);

    assert
      .dom(".d-virtual-list__item[data-index='0']")
      .doesNotExist("no off-window row is added when pinnedIndex is null");
  });
});
