import loadScript from 'discourse/lib/load-script';
import DiscourseURL from 'discourse/lib/url';

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
        } else if (me.name.substr(-10) === "hbs") {

          // Reload handlebars
          const js = me.name.replace(".hbs", "").replace("app/assets/javascripts", "/assets");
          loadScript(js + "?hash=" + me.hash).then(function() {
            const templateName = js.replace(".js", "").replace("/assets/", "");
            return _.each(Ember.View.views, function(view) {
              if (view.get('templateName') === templateName) {
                view.set('templateName', 'empty');
                view.rerender();
                Em.run.schedule('afterRender', function() {
                  view.set('templateName', templateName);
                  view.rerender();
                });
              }
            });
          });

        } else {
          $('link').each(function() {
            // TODO: stop bundling css in DEV please
            if (true || (this.href.match(me.name) && me.hash)) {
              if (!$(this).data('orig')) {
                $(this).data('orig', this.href);
              }
              const orig = $(this).data('orig');
              if (!me.hash) {
                window.__uniq = window.__uniq || 1;
                me.hash = window.__uniq++;
              }
              this.href = orig + (orig.indexOf('?') >= 0 ? "&hash=" : "?hash=") + me.hash;
            }
          });
        }
      });
    });
  }
};
