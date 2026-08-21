import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { findAll, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DVirtualList from "discourse/ui-kit/d-virtual-list";
import {
  disableVirtualization,
  enableVirtualization,
} from "discourse/ui-kit/lib/virtualizer";

const ROW_HEIGHT = 40;
const estimateSize = () => ROW_HEIGHT;

class State {
  @tracked items;

  constructor(items) {
    this.items = items;
  }
}

function buildRows(count) {
  return Array.from({ length: count }, (_, id) => ({
    id: String(id),
    text: `row ${id}`,
  }));
}

module("Integration | ui-kit | DVirtualList | stable key", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    enableVirtualization();
  });

  hooks.afterEach(function () {
    disableVirtualization();
  });

  test("stable @key reuses row DOM across an item-array replacement", async function (assert) {
    const state = new State(buildRows(1000));
    const insertCounts = new Map();
    const recordInsert = (id) => {
      insertCounts.set(id, (insertCounts.get(id) ?? 0) + 1);
    };

    await render(
      <template>
        {{! Size the scroll viewport via CSS: `...attributes` route to the inner
            container, so an inline `style` would size that, not the viewport. }}
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
          @estimateSize={{estimateSize}}
          as |item|
        >
          <div
            class="row"
            data-row-id={{item.id}}
            style="height: 40px"
            {{didInsert (fn recordInsert item.id)}}
          >
            {{item.text}}
          </div>
        </DVirtualList>
      </template>
    );

    const rowsBefore = new Map(
      findAll(".row").map((element) => [element.dataset.rowId, element])
    );
    const insertsBefore = new Map(insertCounts);

    assert.true(rowsBefore.size > 0, "a real window mounts some rows");
    assert.true(
      rowsBefore.size < 40,
      `a real window mounts fewer than 40 rows (${rowsBefore.size} rows)`
    );

    state.items = state.items.map((row) => ({ ...row }));
    await settled();

    const rowsAfter = new Map(
      findAll(".row").map((element) => [element.dataset.rowId, element])
    );

    for (const [id, elementBefore] of rowsBefore) {
      assert.strictEqual(
        insertCounts.get(id),
        insertsBefore.get(id),
        `row ${id} is not inserted again after the replacement`
      );
      assert.strictEqual(
        rowsAfter.get(id),
        elementBefore,
        `row ${id} keeps its DOM element after fresh objects replace the item array`
      );
    }
  });
});
