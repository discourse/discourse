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
import {
  disableVirtualization,
  enableVirtualization,
} from "discourse/ui-kit/-internals/windowing/virtualizer";
import DVirtualList from "discourse/ui-kit/d-virtual-list";

const ROW_PX = 40;
const estimate = () => ROW_PX;

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
          @estimateSize={{estimate}}
          @initialIndex={{500}}
          @items={{items}}
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
            @estimateSize={{estimate}}
            @initialAlign={{align}}
            @initialIndex={{500}}
            @items={{items}}
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
    const items = tracked(buildRows(1000));

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
          @initialIndex={{500}}
          @items={{items.value}}
          @key="id"
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
    items.value = buildRows(1000);
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

  test("an off-window kept-mounted row stays mounted in ascending DOM order", async function (assert) {
    const items = buildRows(100);
    const keepFirst = () => [0];

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
          @itemRole="option"
          @items={{items}}
          @keepMounted={{keepFirst}}
          @key="id"
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
      .exists(
        "the kept-mounted row remains mounted outside the visible window"
      );
    assert.strictEqual(
      indices[0],
      0,
      "the kept-mounted row precedes the bottom window in DOM order"
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

  test("a kept-mounted row inside the visible window is not duplicated", async function (assert) {
    const items = buildRows(100);
    const keepFifth = () => [5];

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
          @items={{items}}
          @keepMounted={{keepFifth}}
          @key="id"
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
        "the visible kept-mounted row has exactly one DOM instance"
      );
  });

  test("a null keepMounted callback renders no extra off-window row", async function (assert) {
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
          @estimateSize={{estimate}}
          @items={{items}}
          @keepMounted={{null}}
          @key="id"
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
      .doesNotExist("no off-window row is added when keepMounted is null");
  });
});

module("Integration | ui-kit | DVirtualList | sticky rows", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    enableVirtualization();
  });

  hooks.afterEach(function () {
    disableVirtualization();
  });

  // The leading rows are taller than the estimate, so a zone computed from estimates alone
  // would be too short once the rows are measured.
  function tallLeadingRows(count) {
    return buildRows(count).map((row) => ({
      ...row,
      tall: row.id < 2,
    }));
  }

  test("leading sticky rows stay mounted and stuck while the list scrolls", async function (assert) {
    const items = tallLeadingRows(200);

    await render(
      <template>
        {{! eslint-disable-next-line ember/template-no-forbidden-elements }}
        <style>
          .d-virtual-list {
            height: 400px;
            overflow-y: auto;
          }
          .row {
            height: 40px;
          }
          .row--tall {
            height: 60px;
          }
        </style>
        <DVirtualList
          @estimateSize={{estimate}}
          @items={{items}}
          @key="id"
          @overscan={{0}}
          @stickyCount={{2}}
          as |item|
        >
          <div class={{if item.tall "row row--tall" "row"}}>{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    await scrollTo(ROW_PX * 150);

    const first = find(".d-virtual-list__item[data-index='0']");
    const second = find(".d-virtual-list__item[data-index='1']");
    assert.true(!!first, "the first sticky row is still mounted");
    assert.true(!!second, "the second sticky row is still mounted");
    assert.strictEqual(
      getComputedStyle(first).position,
      "sticky",
      "the first row is sticky"
    );
    assert.strictEqual(
      getComputedStyle(second).position,
      "sticky",
      "the second row is sticky"
    );
    assert.notStrictEqual(
      getComputedStyle(first).zIndex,
      "auto",
      "sticky rows paint above the rows scrolling under them"
    );

    const viewport = find(".d-virtual-list").getBoundingClientRect();
    const firstRect = first.getBoundingClientRect();
    const secondRect = second.getBoundingClientRect();
    assert.true(
      Math.abs(firstRect.top - viewport.top) < 1,
      "the first row is stuck to the top of the viewport"
    );
    assert.true(
      secondRect.top >= firstRect.bottom - 1,
      "the second row stacks below the first instead of overlapping it"
    );
    const ordinary = findAll(".d-virtual-list__item").find(
      (element) => Number(element.dataset.index) >= 2
    );
    assert.strictEqual(
      getComputedStyle(ordinary).position,
      "absolute",
      "ordinary rows keep their absolute placement"
    );
  });

  test("a throwing keepMounted callback cannot drop the sticky rows", async function (assert) {
    const items = buildRows(200);
    const explode = () => {
      throw new Error("keepMounted callback failed");
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
          @estimateSize={{estimate}}
          @items={{items}}
          @keepMounted={{explode}}
          @key="id"
          @overscan={{0}}
          @stickyCount={{1}}
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    await scrollTo(ROW_PX * 150);

    assert
      .dom(".d-virtual-list__item[data-index='0']")
      .exists("the sticky row stays mounted");
  });

  test("scrolling to a row lands it below the sticky zone", async function (assert) {
    const items = tallLeadingRows(200);
    let api;
    const registerApi = (value) => (api = value);

    await render(
      <template>
        {{! eslint-disable-next-line ember/template-no-forbidden-elements }}
        <style>
          .d-virtual-list {
            height: 400px;
            overflow-y: auto;
          }
          .row {
            height: 40px;
          }
          .row--tall {
            height: 60px;
          }
        </style>
        <DVirtualList
          @estimateSize={{estimate}}
          @items={{items}}
          @key="id"
          @onRegisterApi={{registerApi}}
          @overscan={{0}}
          @stickyCount={{2}}
          as |item|
        >
          <div class={{if item.tall "row row--tall" "row"}}>{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    api.scrollToIndex(50, { align: "start" });
    await settled();
    await new Promise((resolve) => requestAnimationFrame(resolve));
    await settled();

    assert
      .dom(".d-virtual-list__item[data-index='1']")
      .exists("the last sticky row is mounted while the list is scrolled");
    const zoneBottom = find(
      ".d-virtual-list__item[data-index='1']"
    ).getBoundingClientRect().bottom;
    const target = find(".d-virtual-list__item[data-index='50']");
    assert.true(!!target, "the target row is mounted");
    assert.true(
      target.getBoundingClientRect().top >= zoneBottom - 1,
      `the target row starts at or below the zone (${target.getBoundingClientRect().top} vs ${zoneBottom})`
    );
  });
});
