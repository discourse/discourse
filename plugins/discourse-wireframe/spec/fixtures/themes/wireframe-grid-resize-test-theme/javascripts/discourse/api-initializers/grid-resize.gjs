import Heading from "discourse/blocks/builtin/heading";
import Layout from "discourse/blocks/builtin/layout";
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  api.renderBlocks("main-outlet-blocks", [
    {
      block: Layout,
      args: {
        mode: "grid",
        columns: 3,
        rows: 3,
        rowHeight: "120px",
        autoCollapse: "never",
      },
      children: [
        {
          block: Heading,
          args: { text: "Resize this cell" },
          containerArgs: { grid: { column: "2", row: "2" } },
        },
      ],
    },
  ]);
});
