import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import BlockOutlet, {
  _resetOutletLayoutsForTesting,
} from "discourse/blocks/block-outlet";
import Heading from "discourse/blocks/builtin/heading";
import Table from "discourse/blocks/builtin/table";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Blocks | table", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    _resetOutletLayoutsForTesting();
  });

  test("auto-fills cells with unplaced children in reading order", async function (assert) {
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: Table,
          args: { columns: 2, rows: 2 },
          children: [
            { block: Heading, args: { text: "A" } },
            { block: Heading, args: { text: "B" } },
            { block: Heading, args: { text: "C" } },
          ],
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert.dom(".d-block-table tr").exists({ count: 2 }, "renders 2 rows");
    assert
      .dom(".d-block-table td")
      .exists(
        { count: 4 },
        "renders a cell for every position in the 2×2 grid"
      );
    assert
      .dom(".d-block-table td .d-block-heading")
      .exists(
        { count: 3 },
        "places the three children, leaving one cell empty"
      );
  });

  test("an explicitly-placed child spans columns via colspan", async function (assert) {
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: Table,
          args: { columns: 2, rows: 2 },
          children: [
            {
              block: Heading,
              args: { text: "Wide" },
              containerArgs: { grid: { column: "1 / 3", row: "1" } },
            },
            { block: Heading, args: { text: "Below" } },
          ],
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom(".d-block-table td[colspan='2']")
      .exists("the placed child spans both columns")
      .hasText("Wide");
  });

  test("header row renders <th scope='col'> cells", async function (assert) {
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: Table,
          args: { columns: 2, rows: 1, headerRow: true },
          children: [
            { block: Heading, args: { text: "Name" } },
            { block: Heading, args: { text: "Value" } },
          ],
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom(".d-block-table th[scope='col']")
      .exists({ count: 2 }, "the first row's cells are column headers");
    assert.dom(".d-block-table td").doesNotExist("no plain data cells");
  });
});
