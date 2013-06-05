/**
  Functions to help development of Discourse, such as inserting probes

  @class Development
  @namespace Discourse
  @module Discourse
**/
Discourse.Development = {


  /**
    Set up probes for performance measurements.

    @method setupProbes
  **/
  setupProbes: function() {

    // Don't probe if we don't have a console
    if (typeof console === "undefined" || console === null) return;

    var topLevel = function(fn, name) {
      return window.probes.measure(fn, {
        name: name,

        before: function(data, owner, args) {
          if (owner) {
            return window.probes.clear();
          }
        },

        after: function(data, owner, args) {

          if (typeof console === "undefined") return;
          if (console === null) return;

          var f, n, v;
          if (owner && data.time > 10) {

            f = function(name, data) {
              if (data && data.count) return name + " - " + data.count + " calls " + ((data.time + 0.0).toFixed(2)) + "ms";
            };

            if (console.group) {
              console.group(f(name, data));
            } else {
              console.log("");
              console.log(f(name, data));
            }

            var ary = [];
            for (n in window.probes) {
              v = window.probes[n];
              if (n === name || v.time < 1) continue;
              ary.push({ k: n, v: v });
            }
            ary.sortBy(function(item) {
              if (item.v && item.v.time) return -item.v.time;
              return 0;
            }).each(function(item) {
              var output = f("" + item.k, item.v);
              if (output) {
                console.log(output);
              }
            });

            if (console.group) {
              console.groupEnd();
            }
            window.probes.clear();
          }
        }
      });
    };

    //Ember.View.prototype.renderToBuffer = window.probes.measure(Ember.View.prototype.renderToBuffer, "renderToBuffer");
    Discourse.URL.routeTo = topLevel(Discourse.URL.routeTo, "Discourse.URL.routeTo");
    Ember.run.end = topLevel(Ember.run.end, "Ember.run.end");
  },

  /**
    Use the message bus for live reloading of components for faster development.

    @method observeLiveChanges
  **/
  observeLiveChanges: function() {

    // subscribe to any site customizations that are loaded
    $('link.custom-css').each(function() {
      var id, split, stylesheet,
        _this = this;
      split = this.href.split("/");
      id = split[split.length - 1].split(".css")[0];
      stylesheet = this;
      return Discourse.MessageBus.subscribe("/file-change/" + id, function(data) {
        var orig, sp;
        if (!$(stylesheet).data('orig')) {
          $(stylesheet).data('orig', stylesheet.href);
        }
        orig = $(stylesheet).data('orig');
        sp = orig.split(".css?");
        stylesheet.href = sp[0] + ".css?" + data;
      });
    });

    // Custom header changes
    $('header.custom').each(function() {
      var header;
      header = $(this);
      return Discourse.MessageBus.subscribe("/header-change/" + ($(this).data('key')), function(data) {
        return header.html(data);
      });
    });

    // Observe file changes
    return Discourse.MessageBus.subscribe("/file-change", function(data) {
      Ember.TEMPLATES.empty = Handlebars.compile("<div></div>");
      return data.each(function(me) {
        var js;
        if (me === "refresh") {
          return document.location.reload(true);
        } else if (me.name.substr(-10) === "handlebars") {
          js = me.name.replace(".handlebars", "").replace("app/assets/javascripts", "/assets");
          return $LAB.script(js + "?hash=" + me.hash).wait(function() {
            var templateName;
            templateName = js.replace(".js", "").replace("/assets/", "");
            return $.each(Ember.View.views, function() {
              var _this = this;
              if (this.get('templateName') === templateName) {
                this.set('templateName', 'empty');
                this.rerender();
                Em.run.schedule('afterRender', function() {
                  _this.set('templateName', templateName);
                  _this.rerender();
                });
              }
            });
          });
        } else {
          return $('link').each(function() {
            if (this.href.match(me.name) && me.hash) {
              if (!$(this).data('orig')) {
                $(this).data('orig', this.href);
              }
              this.href = $(this).data('orig') + "&hash=" + me.hash;
            }
          });
        }
      });
    });
  }

};