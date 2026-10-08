import Heading from "discourse/blocks/builtin/heading";
import Layout from "discourse/blocks/builtin/layout";
import { apiInitializer } from "discourse/lib/api";

// Seeds a 2×1 grid layout with a single heading (in cell 1; cell 2 left empty
// as a neutral blur target) into the main outlet, so the wireframe editor
// system test has a real `richInline` arg to edit from the inspector. A grid is
// used so the shared editor page object's grid-gated `enter` resolves. The
// heading text starts as a plain string ("Hello world") to prove the lazy
// upgrade to doc-JSON happens only once a mark is applied.
export default apiInitializer((api) => {
  api.renderBlocks("main-outlet-blocks", [
    {
      block: Layout,
      args: { mode: "grid", columns: 2, rows: 1 },
      children: [
        {
          block: Heading,
          args: { text: "Hello world", level: 2 },
          containerArgs: { grid: { column: "1", row: "1" } },
        },
      ],
    },
  ]);
});
