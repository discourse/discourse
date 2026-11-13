import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { trackedObject } from "@ember/reactive/collections";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { trustHTML } from "@ember/template";
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

const ROW_HEIGHT = 40;
const estimateSize = () => ROW_HEIGHT;

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
    const items = tracked(buildRows(1000));
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
          @estimateSize={{estimateSize}}
          @items={{items.value}}
          @key="id"
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

    items.value = items.value.map((row) => ({ ...row }));
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

  test("a row keeps its drawn content when another row leaves the mounted set", async function (assert) {
    const items = buildRows(100);
    // A new function per change, as a consumer passes one per cursor move.
    const kept = trackedObject({ rows: () => [0] });

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
          @estimateSize={{estimateSize}}
          @items={{items}}
          @keepMounted={{kept.rows}}
          @key="id"
          as |item|
        >
          <div class="row" data-row-id={{item.id}} style="height: 40px">
            {{trustHTML (concat "<b class='drawn'>" item.text "</b>")}}
          </div>
        </DVirtualList>
      </template>
    );
    const viewport = find(".d-virtual-list");
    viewport.scrollTop = ROW_HEIGHT * 50;
    await triggerEvent(viewport, "scroll");

    const drawn = find(".row[data-row-id='52'] .drawn");
    assert.dom(".row[data-row-id='0']").exists("the kept row is mounted");
    assert.true(!!drawn, "a row in the window is drawn");

    // Moving the kept row into the window drops the old one, as a press on a row does.
    kept.rows = () => [52];
    await settled();

    assert
      .dom(".row[data-row-id='0']")
      .doesNotExist("the old kept row has left the mounted set");
    assert.true(
      drawn.isConnected,
      "the drawn content of an unchanged row is not rebuilt"
    );
  });
});
