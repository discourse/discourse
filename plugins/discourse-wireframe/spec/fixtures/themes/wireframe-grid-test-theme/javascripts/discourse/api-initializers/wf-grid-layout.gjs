import Layout from "discourse/blocks/builtin/layout";
import { apiInitializer } from "discourse/lib/api";
import {
  WfGridCellA,
  WfGridCellB,
} from "../pre-initializers/register-wf-grid-blocks";

// Seeds a grid layout into the main outlet so the wireframe editor system test
// has a real grid to drag into. The grid is 3×1 with cells A and B placed in
// columns 1 and 2, leaving column 3 empty — the exact shape that exercises a
// "drop between two occupied cells" and a "drop into an empty cell".
export default apiInitializer((api) => {
  api.renderBlocks("main-outlet-blocks", [
    {
      block: Layout,
      args: { mode: "grid", columns: 3, rows: 1 },
      children: [
        { block: WfGridCellA, containerArgs: { grid: { column: "1", row: "1" } } },
        { block: WfGridCellB, containerArgs: { grid: { column: "2", row: "1" } } },
      ],
    },
  ]);
});
