/**
  Use the message bus for live reloading of components for faster development.
**/
export default {
  name: "live-development",
  initialize: function() {

    // subscribe to any site customizations that are loaded
    $('link.custom-css').each(function() {
      var split = this.href.split("/"),
          id = split[split.length - 1].split(".css")[0],
          self = this;

      return Discourse.MessageBus.subscribe("/file-change/" + id, function(data) {
        if (!$(self).data('orig')) {
          $(self).data('orig', self.href);
        }
        var orig = $(self).data('orig'),
            sp = orig.split(".css?");

        self.href = sp[0] + ".css?" + data;
      });
    });

    // Custom header changes
    $('header.custom').each(function() {
      var header = $(this);
      return Discourse.MessageBus.subscribe("/header-change/" + $(this).data('key'), function(data) {
        return header.html(data);
      });
    });

    // Observe file changes
    Discourse.MessageBus.subscribe("/file-change", function(data) {
      Ember.TEMPLATES.empty = Handlebars.compile("<div></div>");
      _.each(data,function(me) {

        if (me === "refresh") {
          // Refresh if necessary
          document.location.reload(true);
        } else if (me.name.substr(-10) === "handlebars") {

          // Reload handlebars
          var js = me.name.replace(".handlebars", "").replace("app/assets/javascripts", "/assets");
          $LAB.script(js + "?hash=" + me.hash).wait(function() {
            var templateName;
            templateName = js.replace(".js", "").replace("/assets/", "");
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
              var orig = $(this).data('orig');
              this.href = orig + (orig.indexOf('?') >= 0 ? "&hash=" : "?hash=") + me.hash;
            }
          });
        }
      });
    });
  }
};
