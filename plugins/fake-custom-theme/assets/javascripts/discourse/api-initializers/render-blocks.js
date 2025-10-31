// This is inside a customer theme

import FeaturedList from "discourse/blocks/featured-list";
import { apiInitializer } from "discourse/lib/api";
import MyBlock from "../blocks/my-block";

export default apiInitializer((api) => {
  api.renderBlockLayout("above-main-container", [
    {
      component: FeaturedList,
      params: {},
    },
    {
      customClass: "yellow-block-featured-list",
      component: FeaturedList,
      params: {
        title: "Overridden title for list",
      },
    },
    {
      group: "my-grouped-blocks",
      blocks: [
        {
          customClass: "block-my-block",
          component: MyBlock,
          params: {},
        },
        {
          customClass: "block-my-block",
          component: MyBlock,
          params: { message: "Second instance of my block" },
        },
      ],
    },

    // {
    //   name: "top-topics",
    //   params: {
    //     count: 5,
    //   },
    // },
  ]);
});
