import { findAll, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DVirtualList from "discourse/ui-kit/d-virtual-list";
import {
  disableVirtualization,
  enableVirtualization,
} from "discourse/ui-kit/lib/virtualizer";

const ROW_PX = 40;
const VIEWPORT_PX = 400;
const COUNT = 100;

// The window must always cover the viewport, whatever `@overscan` arrives.
const MIN_MOUNTED = VIEWPORT_PX / ROW_PX;

const estimate = () => ROW_PX;

function buildRows(count) {
  return Array.from({ length: count }, (_, index) => ({
    id: index,
    text: `row ${index}`,
  }));
}

module(
  "Integration | ui-kit | DVirtualList | overscan input",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      enableVirtualization();
    });

    hooks.afterEach(function () {
      disableVirtualization();
    });

    // A fractional overscan reaches the engine's range extractor, where
    // `new Array(end - start + 1)` gets a fractional length and throws. The
    // engine's memo commits its dependencies before calling the producer, so the
    // throw is cached: every later read short-circuits and the list stays blank
    // for good rather than recovering on the next scroll.
    test("a fractional overscan still mounts a window", async function (assert) {
      const items = buildRows(COUNT);

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
            @overscan={{0.5}}
            as |item|
          >
            <div class="row" style="height: 40px">{{item.text}}</div>
          </DVirtualList>
        </template>
      );

      assert.true(
        findAll(".d-virtual-list__item").length >= MIN_MOUNTED,
        "a fractional overscan still mounts enough rows to fill the viewport"
      );
    });

    test("a NaN overscan still mounts a window", async function (assert) {
      const items = buildRows(COUNT);
      const notANumber = Number.NaN;

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
            @overscan={{notANumber}}
            as |item|
          >
            <div class="row" style="height: 40px">{{item.text}}</div>
          </DVirtualList>
        </template>
      );

      assert.true(
        findAll(".d-virtual-list__item").length >= MIN_MOUNTED,
        "a NaN overscan still mounts enough rows to fill the viewport"
      );
    });

    // Negative overscan does not throw. It shrinks the extracted range from both
    // ends, so the list quietly renders fewer rows than the viewport shows and
    // leaves a strip of blank space instead.
    test("a negative overscan still mounts a window", async function (assert) {
      const items = buildRows(COUNT);

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
            @overscan={{-1}}
            as |item|
          >
            <div class="row" style="height: 40px">{{item.text}}</div>
          </DVirtualList>
        </template>
      );

      assert.true(
        findAll(".d-virtual-list__item").length >= MIN_MOUNTED,
        "a negative overscan still mounts enough rows to fill the viewport"
      );
    });
  }
);
