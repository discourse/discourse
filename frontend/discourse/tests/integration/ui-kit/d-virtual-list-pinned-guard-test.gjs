import { tracked } from "@glimmer/tracking";
import { find, render, settled, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DVirtualList from "discourse/ui-kit/d-virtual-list";
import {
  disableVirtualization,
  enableVirtualization,
} from "discourse/ui-kit/lib/virtualizer";

const ROW_PX = 40;
const estimate = () => ROW_PX;

class Harness {
  @tracked items;
  @tracked pinnedIndex;

  constructor(items, pinnedIndex) {
    this.items = items;
    this.pinnedIndex = pinnedIndex;
  }
}

function buildRows(count) {
  return Array.from({ length: count }, (_, index) => ({
    id: index,
    text: `row ${index}`,
  }));
}

function renderedIndices() {
  return [...document.querySelectorAll(".d-virtual-list__item")]
    .map((el) => Number(el.dataset.index))
    .sort((a, b) => a - b);
}

async function scrollTo(top) {
  const element = find(".d-virtual-list");
  element.scrollTop = top;
  await triggerEvent(element, "scroll");
}

// Supplemental regression coverage for a review finding NOT pinned by the
// decorrelated oracle (d-virtual-list-anchoring-test.gjs): a non-integer
// @pinnedIndex must be inert rather than indexing the engine's measurements with
// a fractional/NaN key (which pushes `undefined` and crashes the state signature).
module(
  "Integration | ui-kit | DVirtualList | pinned index guard",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      enableVirtualization();
    });

    hooks.afterEach(function () {
      disableVirtualization();
    });

    test("a fractional pinnedIndex is inert and does not crash", async function (assert) {
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
            @estimateSize={{estimate}}
            @pinnedIndex={{1.5}}
            @overscan={{0}}
            as |item|
          >
            <div class="row" style="height: 40px">{{item.text}}</div>
          </DVirtualList>
        </template>
      );

      await scrollTo(ROW_PX * 100);

      assert
        .dom(".d-virtual-list__item")
        .exists(
          "the list renders without crashing on a fractional pinnedIndex"
        );
      assert
        .dom(".d-virtual-list__item[data-index='1']")
        .doesNotExist("a fractional index pins nothing");
    });

    // Regression for a reported gap: filtering a large list down to a single match
    // and then widening the filter (e.g. "1356" → backspace → "135") left a visible
    // hole right after the active row. The active row is pinned, and the engine had
    // kept the scroll offset from before the filter shrank the list, so it computed
    // a window far down while `@pinnedIndex` force-rendered the active row at the
    // top — the rows between were never mounted. The window must track the element's
    // real (browser-clamped) offset after the set changes, leaving no gap.
    test("a pinned row leaves no gap after the item set shrinks then grows", async function (assert) {
      const h = new Harness(buildRows(30), 0);

      await render(
        <template>
          {{! eslint-disable-next-line ember/template-no-forbidden-elements }}
          <style>
            .d-virtual-list {
              height: 320px;
              overflow-y: auto;
            }
          </style>
          <DVirtualList
            @items={{h.items}}
            @key="id"
            @estimateSize={{estimate}}
            @pinnedIndex={{h.pinnedIndex}}
            as |item|
          >
            <div class="row" style="height: 40px">{{item.text}}</div>
          </DVirtualList>
        </template>
      );

      // Scroll away from the pinned row, then filter down to a single match and
      // widen it again — the sequence that stranded the stale offset.
      await scrollTo(ROW_PX * 8);
      h.items = buildRows(1);
      await settled();
      h.items = buildRows(15);
      await settled();

      const indices = renderedIndices();
      assert.deepEqual(
        indices,
        Array.from({ length: indices.length }, (_, i) => i),
        `rendered rows are contiguous from the pinned index (got [${indices}])`
      );
    });
  }
);
