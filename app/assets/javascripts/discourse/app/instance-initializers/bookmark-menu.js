import { withPluginApi } from "discourse/lib/plugin-api";
import PostBookmarkManager from "discourse/lib/post-bookmark-manager";

export default {
  name: "discourse-bookmark-menu",

  initialize(container) {
    withPluginApi("0.10.1", (api) => {
      api.replacePostMenuButton("bookmark", {
        name: "bookmark-menu-shim",
        shouldRender: () => true,
        buildAttrs: (widget) => {
          return {
            post: widget.findAncestorModel(),
            bookmarkManager: new PostBookmarkManager(
              container,
              widget.findAncestorModel()
            ),
          };
        },
      });
    });
  },
};
