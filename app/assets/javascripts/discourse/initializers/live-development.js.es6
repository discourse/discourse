import DiscourseURL from 'discourse/lib/url';
import { currentThemeKey, refreshCSS } from 'discourse/lib/theme-selector';

//  Use the message bus for live reloading of components for faster development.
export default {
  name: "live-development",
  initialize(container) {
    const messageBus = container.lookup('message-bus:main');

    // subscribe to any site customizations that are loaded
    $('link.custom-css').each(function() {
      const split = this.href.split("/"),
          id = split[split.length - 1].split(".css")[0],
          self = this;

      return messageBus.subscribe("/file-change/" + id, function(data) {
        if (!$(self).data('orig')) {
          $(self).data('orig', self.href);
        }
        const orig = $(self).data('orig');

        self.href = orig.replace(/v=.*/, "v=" + data);
      });
    });

    // Custom header changes
    $('header.custom').each(function() {
      const header = $(this);
      return messageBus.subscribe("/header-change/" + $(this).data('key'), function(data) {
        return header.html(data);
      });
    });

    // Useful to export this for debugging purposes
    if (Discourse.Environment === 'development' && !Ember.testing) {
      window.DiscourseURL = DiscourseURL;
    }

    // Observe file changes
    messageBus.subscribe("/file-change", function(data) {
      if (Handlebars.compile && !Ember.TEMPLATES.empty) {
        // hbs notifications only happen in dev
        Ember.TEMPLATES.empty = Handlebars.compile("<div></div>");
      }
      _.each(data,function(me) {

        if (me === "refresh") {
          // Refresh if necessary
          document.location.reload(true);
        } else {
          let themeKey = currentThemeKey();

          $('link').each(function() {
            if (me.hasOwnProperty('theme_key') && me.new_href) {
              let target = $(this).data('target');
              if (me.theme_key === themeKey && target === me.target) {
                refreshCSS(this, null, me.new_href);
              }
            }
            else if (this.href.match(me.name) && (me.hash || me.new_href)) {
              refreshCSS(this, me.hash, me.new_href);
            }
          });
        }
      });
    });
  }
};
