// This is inside a customer theme

import FeaturedList from "discourse/blocks/featured-list";
import PoweredByDiscourse from "discourse/components/powered-by-discourse";
import { apiInitializer } from "discourse/lib/api";
import MyBlock from "../blocks/my-block";

export default apiInitializer((api) => {
  api.renderBlockLayout("above-main-container", [
    {
      name: "block-featured-list",
      component: FeaturedList,
      params: {},
    },
    {
      name: "yellow-block-featured-list",
      component: FeaturedList,
      params: {},
    },
    {
      name: "block-my-block",
      component: MyBlock,
      params: {},
    },
    // {
    //   name: "top-topics",
    //   params: {
    //     count: 5,
    //   },
    // },
  ]);
});
