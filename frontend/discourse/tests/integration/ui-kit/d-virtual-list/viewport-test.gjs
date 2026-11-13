import { tracked } from "@glimmer/tracking";
import { trustHTML } from "@ember/template";
import { find, render, settled } from "@ember/test-helpers";
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

module("Integration | ui-kit | DVirtualList | viewport", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    enableVirtualization();
  });

  hooks.afterEach(function () {
    disableVirtualization();
  });

  // Splattributes go to the inner semantic container, so the scroll viewport is
  // unreachable: the element whose height the consumer owns, and which a browser
  // may adopt as a tab stop, can carry neither a hook nor a name. Every consumer
  // in the repo reaches through the internal class name from an ancestor instead.
  test("viewport hooks: @viewportClass lands on the scroll viewport", async function (assert) {
    const items = buildRows(50);

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
          @key="id"
          @viewportClass="my-scroller"
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    assert
      .dom(".d-virtual-list.my-scroller")
      .exists("the consumer's class joins the viewport's own");
    assert
      .dom(".d-virtual-list__sizer.my-scroller")
      .doesNotExist("it does not land on the inner container instead");
  });

  // A non-interactive role leaves nothing inside focusable, so the component's own
  // documentation tells the consumer to make the viewport focusable and name it.
  // Until now the API could express neither half of that instruction.
  test("viewport hooks: @viewportLabel names the scroll viewport", async function (assert) {
    const items = buildRows(50);

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
          @key="id"
          @viewportLabel="Search results"
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    assert
      .dom(".d-virtual-list")
      .hasAttribute(
        "aria-label",
        "Search results",
        "the scrollable region carries an accessible name"
      );
    // A name on a role-less div is prohibited by ARIA: the implicit `generic`
    // role cannot be named, so the attribute is decorative without a role that
    // permits naming.
    assert
      .dom(".d-virtual-list")
      .hasAttribute(
        "role",
        "region",
        "and a role that is allowed to carry that name"
      );
  });

  test("viewport hooks: an unnamed viewport stays role-less", async function (assert) {
    const items = buildRows(50);

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
          @key="id"
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    // The role exists to make a name legal, so a viewport with no name must not
    // gain one: a landmark per list would clutter the document's structure.
    assert
      .dom(".d-virtual-list")
      .doesNotHaveAttribute(
        "role",
        "an unnamed viewport adds no landmark to the page"
      );
  });

  test("viewport hooks: @viewportLabelledBy names it from existing markup", async function (assert) {
    const items = buildRows(50);

    await render(
      <template>
        {{! eslint-disable-next-line ember/template-no-forbidden-elements }}
        <style>
          .d-virtual-list {
            height: 400px;
            overflow-y: auto;
          }
        </style>
        <h2 id="results-heading">Results</h2>
        <DVirtualList
          @estimateSize={{estimate}}
          @items={{items}}
          @key="id"
          @viewportLabelledBy="results-heading"
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    assert
      .dom(".d-virtual-list")
      .hasAttribute("aria-labelledby", "results-heading");
    assert
      .dom(".d-virtual-list")
      .hasAttribute(
        "role",
        "region",
        "either naming argument earns the role that permits a name"
      );
  });

  // The existing split is deliberate and must survive: the semantic element owns
  // the role and the consumer's own attributes.
  test("viewport hooks: splattributes still reach the inner container", async function (assert) {
    const items = buildRows(50);

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
          data-container="yes"
          @estimateSize={{estimate}}
          @items={{items}}
          @key="id"
          @viewportClass="my-scroller"
          as |item|
        >
          <div class="row" style="height: 40px">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    assert
      .dom(".d-virtual-list__sizer")
      .hasAttribute(
        "data-container",
        "yes",
        "consumer attributes still land on the semantic container"
      );
    assert.strictEqual(
      find(".d-virtual-list").getAttribute("data-container"),
      null,
      "and not on the viewport"
    );
  });
});

module(
  "Integration | ui-kit | DVirtualList | sticky leading count changes",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(() => enableVirtualization());
    hooks.afterEach(() => disableVirtualization());

    test("changing the count repositions retained rows and updates measured scroll padding", async function (assert) {
      const count = tracked(2);
      const height = tracked(60);
      const items = buildRows(100);
      const rowStyle = (size) => trustHTML(`height: ${size}px`);
      let api;
      const register = (value) => (api = value);

      await render(
        <template>
          {{! eslint-disable-next-line ember/template-no-forbidden-elements }}
          <style>
            .d-virtual-list {
              height: 200px;
              overflow-y: auto;
            }
          </style>
          <DVirtualList
            @estimateSize={{estimate}}
            @items={{items}}
            @key="id"
            @onRegisterApi={{register}}
            @stickyCount={{count.value}}
            as |item|
          >
            <div style={{rowStyle height.value}}>{{item.text}}</div>
          </DVirtualList>
        </template>
      );

      const row = () => find(".d-virtual-list__item[data-index='1']");
      const padding = () =>
        parseFloat(getComputedStyle(find(".d-virtual-list")).scrollPaddingTop);
      assert.strictEqual(
        padding(),
        120,
        "the zone uses measured heights rather than estimates"
      );
      count.value = 1;
      await settled();
      assert.strictEqual(
        row().style.position,
        "absolute",
        "a retained row stops sticking"
      );
      assert.strictEqual(
        row().style.zIndex,
        "",
        "the former sticky row clears its stacking order"
      );
      assert.strictEqual(
        row().style.top,
        "0px",
        "absolute placement resets the sticky offset"
      );
      assert.strictEqual(padding(), 60, "padding shrinks with the zone");
      height.value = 80;
      await settled();
      api.measure();
      await settled();
      assert.strictEqual(padding(), 80, "padding follows a sticky row resize");
      count.value = 0;
      await settled();
      assert.strictEqual(
        padding(),
        0,
        "removing stickiness clears scroll padding"
      );
      count.value = 2;
      await settled();
      assert.strictEqual(
        row().style.position,
        "sticky",
        "a retained row starts sticking again"
      );
      assert.strictEqual(
        padding(),
        160,
        "the rebuilt zone uses both measured rows"
      );
      api.scrollToIndex(50, { align: "start" });
      await settled();
      const target = find(
        ".d-virtual-list__item[data-index='50']"
      ).getBoundingClientRect();
      assert.true(
        target.top >= row().getBoundingClientRect().bottom - 1,
        "imperative reveal uses the resized zone"
      );
    });
  }
);
