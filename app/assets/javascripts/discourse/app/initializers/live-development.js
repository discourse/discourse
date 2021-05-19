import DiscourseURL from "discourse/lib/url";
import Handlebars from "handlebars";
import { isDevelopment } from "discourse-common/config/environment";
import { refreshCSS } from "discourse/lib/theme-selector";

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

    // Custom header changes
    $("header.custom").each(function () {
      const header = $(this);
      return messageBus.subscribe(
        "/header-change/" + $(this).data("id"),
        function (data) {
          return header.html(data);
        }
      );
    });

    // Useful to export this for debugging purposes
    if (isDevelopment()) {
      window.DiscourseURL = DiscourseURL;
    }

    // Observe file changes
    messageBus.subscribe(
      "/file-change",
      function (data) {
        if (Handlebars.compile && !Ember.TEMPLATES.empty) {
          // hbs notifications only happen in dev
          Ember.TEMPLATES.empty = Handlebars.compile("<div></div>");
        }
        data.forEach((me) => {
          if (me === "refresh") {
            // Refresh if necessary
            document.location.reload(true);
          } else {
            $("link").each(function () {
              if (me.hasOwnProperty("theme_id") && me.new_href) {
                const target = $(this).data("target");
                const themeId = $(this).data("theme-id");
                if (
                  target === me.target &&
                  (!themeId || themeId === me.theme_id)
                ) {
                  refreshCSS(this, null, me.new_href);
                }
              } else if (this.href.match(me.name) && (me.hash || me.new_href)) {
                refreshCSS(this, me.hash, me.new_href);
              }
            });
          }
        });
      },
      session.mbLastFileChangeId
    );
  },
};
