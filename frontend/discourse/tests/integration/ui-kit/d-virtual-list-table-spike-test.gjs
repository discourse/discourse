import { array } from "@ember/helper";
import { find, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DVirtualListTableSpike from "discourse/ui-kit/d-virtual-list-table-spike";
import {
  disableVirtualization,
  enableVirtualization,
} from "discourse/ui-kit/lib/virtualizer";

// SPIKE test — confirms the virtualized <table> windows correctly: only a slice of
// data <tr> rows mounts, bracketed by two spacer rows, and the window tracks the
// scroll offset. Validates that the two-table (fixed head + scrolling body) structure
// drives virtual-core the same way the div-based spike does.

const ROW_PX = 40;
const estimate = () => ROW_PX;

function buildRows(count) {
  return Array.from({ length: count }, (_, index) => ({
    id: index,
    name: `User ${index}`,
  }));
}

function dataIndices() {
  return [
    ...document.querySelectorAll(".d-virtual-list tbody tr[data-index]"),
  ].map((el) => Number(el.dataset.index));
}

async function scrollTo(top) {
  const element = find(".d-virtual-list");
  element.scrollTop = top;
  await triggerEvent(element, "scroll");
}

module("Integration | ui-kit | DVirtualListTableSpike", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    enableVirtualization();
    // A virtualized <table> resizes its spacer rows on scroll, which reflows the
    // table and makes the browser emit the benign "ResizeObserver loop completed
    // with undelivered notifications" warning — harmless (the loop completes) but
    // an uncaught global error the harness would otherwise fail on. Swallow only
    // that specific message; a real re-measurement loop would hang, not warn.
    this.ignoreResizeLoop = (event) => {
      if (event.message?.includes("ResizeObserver loop")) {
        event.stopImmediatePropagation();
        event.preventDefault();
      }
    };
    window.addEventListener("error", this.ignoreResizeLoop, true);
  });

  hooks.afterEach(function () {
    window.removeEventListener("error", this.ignoreResizeLoop, true);
    disableVirtualization();
  });

  test("windows the table body and brackets it with spacer rows", async function (assert) {
    const rows = buildRows(1000);

    await render(
      <template>
        {{! eslint-disable-next-line ember/template-no-forbidden-elements }}
        <style>
          .d-virtual-list {
            height: 400px;
            overflow-y: auto;
          }
        </style>
        <DVirtualListTableSpike
          @items={{rows}}
          @key="id"
          @estimateSize={{estimate}}
          @overscan={{0}}
          @columnWidths={{array "50%" "50%"}}
        >
          <:header>
            <th>ID</th>
            <th>Name</th>
          </:header>
          <:default as |user|>
            {{! Fixed row height matching the estimate: a table can't measure-and-
                reflow without churning the ResizeObserver, so it wants deterministic
                heights. }}
            <td style="padding: 0">
              <div style="height: 40px; line-height: 40px">{{user.id}}</div>
            </td>
            <td style="padding: 0">
              <div style="height: 40px; line-height: 40px">{{user.name}}</div>
            </td>
          </:default>
        </DVirtualListTableSpike>
      </template>
    );

    assert
      .dom(".d-virtual-table__head th")
      .exists({ count: 2 }, "the sticky header renders its columns");

    await scrollTo(ROW_PX * 500);

    const indices = dataIndices();
    assert.true(indices.length > 0, "a window of rows mounts");
    assert.true(
      indices.length < 40,
      `only a window mounts, not all 1000 (${indices.length} rows)`
    );
    // Within a couple of rows: exact boundary depends on table measurement
    // (border-spacing, cell padding), but the window clearly tracks the offset.
    assert.true(
      Math.abs(indices[0] - 500) <= 2,
      `the first mounted row (${indices[0]}) tracks the scroll offset (~500)`
    );
    assert
      .dom(".d-virtual-table__spacer")
      .exists({ count: 2 }, "a top and bottom spacer row bracket the window");
  });
});
