import Layout from "discourse/blocks/builtin/layout";
import Paragraph from "discourse/blocks/builtin/paragraph";
import Tabs from "discourse/blocks/builtin/tabs";
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  api.renderBlocks("main-outlet-blocks", [
    {
      block: Tabs,
      children: Array.from({ length: 10 }, (_, index) => ({
        block: Layout,
        containerArgs: { tab: { label: `Community collection ${index + 1}` } },
        children: [{ block: Paragraph, args: { text: `Collection ${index + 1} content` } }],
      })),
    },
  ]);
});
