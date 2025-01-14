import { setOwner } from "@ember/owner";
import { service } from "@ember/service";
import { bind } from "discourse/lib/decorators";
import discourseLater from "discourse/lib/later";

// Use the message bus for live reloading of components for faster development.
class LiveDevelopmentInit {
  @service messageBus;
  @service session;

  constructor(owner) {
    setOwner(this, owner);

    const PRESERVED_QUERY_PARAMS = ["preview_theme_id", "pp", "safe_mode"];
    const params = new URLSearchParams(window.location.search);
    const preservedParamValues = PRESERVED_QUERY_PARAMS.map((p) => [
      p,
      params.get(p),
    ]).filter(([, v]) => v);
    if (preservedParamValues.length) {
      ["replaceState", "pushState"].forEach((funcName) => {
        const originalFunc = window.history[funcName];

        window.history[funcName] = (stateObj, name, rawUrl) => {
          const url = new URL(rawUrl, window.location);
          for (const [param, value] of preservedParamValues) {
            url.searchParams.set(param, value);
          }

          return originalFunc.call(window.history, stateObj, name, url.href);
        };
      });
    }

    // Observe file changes
    this.messageBus.subscribe(
      "/file-change",
      this.onFileChange,
      this.session.mbLastFileChangeId
    );
  }

  teardown() {
    this.messageBus.unsubscribe("/file-change", this.onFileChange);
  }

  @bind
  onFileChange(data) {
    data.forEach((me) => {
      if (me === "refresh") {
        // Refresh if necessary
        document.location.reload(true);
      } else if (me === "development-mode-theme-changed") {
        if (
          window.location.pathname.startsWith("/admin/customize/themes") ||
          window.location.pathname.startsWith("/admin/config/look-and-feel")
        ) {
          // Don't refresh users on routes which make theme changes - would be very inconvenient.
          // Instead, refresh on their next route navigation.
          this.session.requiresRefresh = true;
        } else {
          document.location.reload(true);
        }
      } else if (me.new_href && me.target) {
        let query = `link[data-target='${me.target}']`;

        if (me.theme_id) {
          query += `[data-theme-id='${me.theme_id}']`;
        }

        const links = document.querySelectorAll(query);

        if (links.length > 0) {
          const lastLink = links[links.length - 1];

          // this check is useful when message-bus has multiple file updates
          // it avoids the browser doing a lot of work for nothing
          // should the filenames be unchanged
          if (lastLink.href.split("/").pop() !== me.new_href.split("/").pop()) {
            this.refreshCSS(lastLink, me.new_href);
          }
        }
      }
    });
  }

  refreshCSS(node, newHref) {
    const reloaded = node.cloneNode(true);
    reloaded.href = newHref;
    node.insertAdjacentElement("afterend", reloaded);
    discourseLater(() => node?.parentNode?.removeChild(node), 500);
  }
}

export default {
  initialize(owner) {
    this.instance = new LiveDevelopmentInit(owner);
  },
  teardown() {
    this.instance.teardown();
    this.instance = null;
  },
};
