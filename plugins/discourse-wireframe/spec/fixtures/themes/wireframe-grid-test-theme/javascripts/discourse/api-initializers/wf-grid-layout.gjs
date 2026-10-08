import Layout from "discourse/blocks/builtin/layout";
import { apiInitializer } from "discourse/lib/api";
import {
  WfGridCellA,
  WfGridCellB,
} from "../pre-initializers/register-wf-grid-blocks";

/**
 * Seeds a 3×1 grid with nested grid A, block B, and one empty cell.
 * The nested grid adds selection coverage without changing the drag targets.
 */
export default apiInitializer((api) => {
  api.renderBlocks("main-outlet-blocks", [
    {
      block: Layout,
      args: { mode: "grid", columns: 3, rows: 1 },
      children: [
        {
          block: Layout,
          args: { mode: "grid", columns: 1, rows: 1 },
          containerArgs: { grid: { column: "1", row: "1" } },
          children: [
            {
              block: WfGridCellA,
              containerArgs: { grid: { column: "1", row: "1" } },
            },
          ],
        },
        { block: WfGridCellB, containerArgs: { grid: { column: "2", row: "1" } } },
      ],
    },
  ]);
});
