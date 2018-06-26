import DiscourseURL from "discourse/lib/url";
import { currentThemeKey, refreshCSS } from "discourse/lib/theme-selector";

//  Use the message bus for live reloading of components for faster development.
export default {
  name: "live-development",
  initialize(container) {
    const messageBus = container.lookup("message-bus:main");

    if (
      window.history &&
      window.location.search.indexOf("?preview_theme_key=") === 0
    ) {
      // force preview theme key to always be carried along
      const themeKey = window.location.search.slice(19).split("&")[0];
      if (themeKey.match(/^[a-z0-9-]+$/i)) {
        const patchState = function(f) {
          const patched = window.history[f];

          window.history[f] = function(stateObj, name, url) {
            if (url.indexOf("preview_theme_key=") === -1) {
              const joiner = url.indexOf("?") === -1 ? "?" : "&";
              url = `${url}${joiner}preview_theme_key=${themeKey}`;
            }

            return patched.call(window.history, stateObj, name, url);
          };
        };
        patchState("replaceState");
        patchState("pushState");
      }
    }

    // Custom header changes
    $("header.custom").each(function() {
      const header = $(this);
      return messageBus.subscribe(
        "/header-change/" + $(this).data("key"),
        function(data) {
          return header.html(data);
        }
      );
    });

    // Useful to export this for debugging purposes
    if (Discourse.Environment === "development" && !Ember.testing) {
      window.DiscourseURL = DiscourseURL;
    }

    // Observe file changes
    messageBus.subscribe("/file-change", function(data) {
      if (Handlebars.compile && !Ember.TEMPLATES.empty) {
        // hbs notifications only happen in dev
        Ember.TEMPLATES.empty = Handlebars.compile("<div></div>");
      }
      _.each(data, function(me) {
        if (me === "refresh") {
          // Refresh if necessary
          document.location.reload(true);
        } else {
          let themeKey = currentThemeKey();

          $("link").each(function() {
            if (me.hasOwnProperty("theme_key") && me.new_href) {
              let target = $(this).data("target");
              if (me.theme_key === themeKey && target === me.target) {
                refreshCSS(this, null, me.new_href);
              }
            } else if (this.href.match(me.name) && (me.hash || me.new_href)) {
              refreshCSS(this, me.hash, me.new_href);
            }
          });
        }
      });
    });
  }
};
