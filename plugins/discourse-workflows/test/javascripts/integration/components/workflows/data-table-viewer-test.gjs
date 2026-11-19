import {
  blur,
  click,
  fillIn,
  find,
  findAll,
  render,
  settled,
  triggerKeyEvent,
  waitUntil,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, {
  parsePostData,
  response,
} from "discourse/tests/helpers/create-pretender";
import DataTableViewer from "discourse/plugins/discourse-workflows/admin/components/workflows/data-table/viewer";

const BASE_PATH = "/admin/plugins/discourse-workflows/data-tables/1";
const CELL_INPUT = ".workflows-data-table-viewer__cell-input";
const CELL_VALUE = ".workflows-data-table-viewer__cell-value";

module("Integration | Component | DataTableViewer", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.row = { id: 1, first: "a", second: "b" };
    this.savedData = [];

    pretender.get(`${BASE_PATH}.json`, () =>
      response({
        data_table: {
          id: 1,
          name: "Contacts",
          columns: [
            { name: "first", type: "string" },
            { name: "second", type: "string" },
          ],
        },
      })
    );
    pretender.get(`${BASE_PATH}/rows.json`, () =>
      response({ rows: [this.row], count: 1 })
    );
    pretender.put(`${BASE_PATH}/rows/1.json`, async (request) => {
      const { data } = parsePostData(request.requestBody);
      this.savedData.push(data);
      await this.pendingSave;
      this.row = { ...this.row, ...data };
      return response({ row: this.row });
    });
  });

  test("saves edits made to successive cells of a row", async function (assert) {
    await render(<template><DataTableViewer @dataTableId={{1}} /></template>);

    const [firstCell, secondCell] = findAll(CELL_VALUE);

    await click(firstCell);
    await fillIn(CELL_INPUT, "a2");
    await triggerKeyEvent(CELL_INPUT, "keydown", "Enter");
    await click(secondCell);
    await fillIn(CELL_INPUT, "b2");
    await blur(CELL_INPUT);

    assert.deepEqual(this.savedData, [{ first: "a2" }, { second: "b2" }]);
  });

  test("keeps an edit when its cell is reopened before the save completes", async function (assert) {
    let completeSave;
    this.pendingSave = new Promise((resolve) => (completeSave = resolve));

    await render(<template><DataTableViewer @dataTableId={{1}} /></template>);

    await click(CELL_VALUE);
    await fillIn(CELL_INPUT, "a2");
    blur(CELL_INPUT);
    await waitUntil(() => this.savedData.length === 1);

    find(CELL_VALUE).click();
    completeSave();
    await settled();
    await blur(CELL_INPUT);

    assert.dom(CELL_VALUE).hasText("a2");
  });
});
