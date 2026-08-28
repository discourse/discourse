import { findAll, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DVirtualList from "discourse/ui-kit/d-virtual-list";
import {
  disableVirtualization,
  enableVirtualization,
} from "discourse/ui-kit/lib/virtualizer";

const ROW_PX = 40;
const OVERSCAN = 5;
const estimate = () => ROW_PX;

function buildRows(count) {
  return Array.from({ length: count }, (_, index) => ({
    id: index,
    text: `row ${index}`,
  }));
}

function mountedIndices() {
  return findAll(".d-virtual-list__item")
    .map((row) => Number(row.dataset.index))
    .sort((a, b) => a - b);
}

// Supplemental coverage: every explicit @overscan in the suite is 0 or a value
// that normalizes to 0, and the counts elsewhere are inequalities that hold at 0,
// so the whole suite passes with the overscan hardcoded to 0.
module(
  "Integration | ui-kit | DVirtualList | overscan window",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      enableVirtualization();
    });

    hooks.afterEach(function () {
      disableVirtualization();
    });

    test("a positive @overscan mounts that many rows beyond the viewport", async function (assert) {
      const items = buildRows(200);

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
            @overscan={{0}}
            as |item|
          >
            <div class="row" style="height: 40px">{{item.text}}</div>
          </DVirtualList>
        </template>
      );

      const withoutOverscan = mountedIndices();

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
            @overscan={{OVERSCAN}}
            as |item|
          >
            <div class="row" style="height: 40px">{{item.text}}</div>
          </DVirtualList>
        </template>
      );

      const withOverscan = mountedIndices();

      // At the top of the list there is nothing to overscan above, so the extra
      // rows all land below. Derived from the measured window rather than a
      // literal, so the assertion survives a viewport or row-height change.
      assert.strictEqual(
        withOverscan.length,
        withoutOverscan.length + OVERSCAN,
        `@overscan={{${OVERSCAN}}} mounts ${OVERSCAN} rows more than @overscan={{0}}`
      );
      assert.strictEqual(
        withOverscan.at(-1),
        withoutOverscan.at(-1) + OVERSCAN,
        "and they extend the window past the last visible row"
      );
      assert.strictEqual(
        withOverscan[0],
        withoutOverscan[0],
        "without moving its start, since the list is scrolled to the top"
      );
    });
  }
);
