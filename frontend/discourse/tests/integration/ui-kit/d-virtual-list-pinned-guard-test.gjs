import { find, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DVirtualList from "discourse/ui-kit/d-virtual-list";
import {
  disableVirtualization,
  enableVirtualization,
} from "discourse/ui-kit/lib/virtualizer";

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
  }
);
