import DiscourseURL from "discourse/lib/url";
import { isDevelopment } from "discourse-common/config/environment";
import discourseLater from "discourse-common/lib/later";

//  Use the message bus for live reloading of components for faster development.
export default {
  name: "live-development",

  initialize(container) {
    const messageBus = container.lookup("message-bus:main");
    const session = container.lookup("session:main");

    // Preserve preview_theme_id=## and pp=async-flamegraph parameters across pages
    const params = new URLSearchParams(window.location.search);
    const previewThemeId = params.get("preview_theme_id");
    const flamegraph = params.get("pp") === "async-flamegraph";
    if (flamegraph || previewThemeId !== null) {
      ["replaceState", "pushState"].forEach((funcName) => {
        const originalFunc = window.history[funcName];

        window.history[funcName] = (stateObj, name, rawUrl) => {
          const url = new URL(rawUrl, window.location);
          if (previewThemeId !== null) {
            url.searchParams.set("preview_theme_id", previewThemeId);
          }
          if (flamegraph) {
            url.searchParams.set("pp", "async-flamegraph");
          }

          return originalFunc.call(window.history, stateObj, name, url.href);
        };
      });
    }

    // Useful to export this for debugging purposes
    if (isDevelopment()) {
      window.DiscourseURL = DiscourseURL;
    }

    // Observe file changes
    messageBus.subscribe(
      "/file-change",
      (data) => {
        data.forEach((me) => {
          if (me === "refresh") {
            // Refresh if necessary
            document.location.reload(true);
          } else if (me.new_href && me.target) {
            const link_target = !!me.theme_id
              ? `[data-target='${me.target}'][data-theme-id='${me.theme_id}']`
              : `[data-target='${me.target}']`;

            const links = document.querySelectorAll(`link${link_target}`);
            if (links.length > 0) {
              const lastLink = links[links.length - 1];
              // this check is useful when message-bus has multiple file updates
              // it avoids the browser doing a lot of work for nothing
              // should the filenames be unchanged
              if (
                lastLink.href.split("/").pop() !== me.new_href.split("/").pop()
              ) {
                this.refreshCSS(lastLink, me.new_href);
              }
            }
          }
        });
      },
      session.mbLastFileChangeId
    );
  },

  refreshCSS(node, newHref) {
    const reloaded = node.cloneNode(true);
    reloaded.href = newHref;
    node.insertAdjacentElement("afterend", reloaded);
    discourseLater(() => node?.parentNode?.removeChild(node), 500);
  },
};
