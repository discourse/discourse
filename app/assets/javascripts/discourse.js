/*global Modernizr:true*/
(function() {
  var csrf_token;

  window.Discourse = Ember.Application.createWithMixins({
    rootElement: '#main',

    // Data we want to remember for a short period    
    transient: Em.Object.create(),

    hasFocus: true,
    scrolling: false,

    // The highest seen post number by topic
    highestSeenByTopic: {},

    logoSmall: (function() {
      var logo;
      logo = Discourse.SiteSettings.logo_small_url;
      if (logo && logo.length > 1) {
        return "<img src='" + logo + "' width='33' height='33'>";
      } else {
        return "<i class='icon-home'></i>";
      }
    }).property(),

    titleChanged: (function() {
      var title;
      title = "";
      if (this.get('title')) {
        title += "" + (this.get('title')) + " - ";
      }
      title += Discourse.SiteSettings.title;
      jQuery('title').text(title);
      if (!this.get('hasFocus') && this.get('notify')) {
        title = "(*) " + title;
      }
      // chrome bug workaround see: http://stackoverflow.com/questions/2952384/changing-the-window-title-when-focussing-the-window-doesnt-work-in-chrome
      window.setTimeout((function() {
        document.title = ".";
        document.title = title;
      }), 200);
    }).observes('title', 'hasFocus', 'notify'),

    currentUserChanged: (function() {
      var bus, user;
      bus = Discourse.MessageBus;

      // We don't want to receive any previous user notidications
      bus.unsubscribe("/notification");
      bus.callbackInterval = Discourse.SiteSettings.anon_polling_interval;
      bus.enableLongPolling = false;
      user = this.get('currentUser');
      if (user) {
        bus.callbackInterval = Discourse.SiteSettings.polling_interval;
        bus.enableLongPolling = true;
        if (user.admin) {
          bus.subscribe("/flagged_counts", function(data) {
            return user.set('site_flagged_posts_count', data.total);
          });
        }
        return bus.subscribe("/notification", (function(data) {
          user.set('unread_notifications', data.unread_notifications);
          return user.set('unread_private_messages', data.unread_private_messages);
        }), user.notification_channel_position);
      }
    }).observes('currentUser'),
    notifyTitle: function() {
      return this.set('notify', true);
    },

    // Browser aware replaceState
    replaceState: function(path) {
      if (window.history && 
          window.history.pushState && 
          window.history.replaceState && 
          !navigator.userAgent.match(/((iPod|iPhone|iPad).+\bOS\s+[1-4]|WebApps\/.+CFNetwork)/)) {
        if (window.location.pathname !== path) {
          return history.replaceState({
            path: path
          }, null, path);
        }
      }
    },

    openComposer: function(opts) {
      // TODO, remove container link
      var composer = Discourse.__container__.lookup('controller:composer');
      if (composer) composer.open(opts);
    },

    // Like router.route, but allow full urls rather than relative one
    // HERE BE HACKS - uses the ember container for now until we can do this nicer.
    routeTo: function(path) {
      var newMatches, newTopicId, oldMatches, oldTopicId, opts, router, topicController, topicRegexp;
      path = path.replace(/https?\:\/\/[^\/]+/, '');

      // If we're in the same topic, don't push the state
      topicRegexp = /\/t\/([^\/]+)\/(\d+)\/?(\d+)?/;
      newMatches = topicRegexp.exec(path);
      if (newTopicId = newMatches ? newMatches[2] : void 0) {
        oldMatches = topicRegexp.exec(window.location.pathname);
        if ((oldTopicId = oldMatches ? oldMatches[2] : void 0) && (oldTopicId === newTopicId)) {
          Discourse.replaceState(path);
          topicController = Discourse.__container__.lookup('controller:topic');
          opts = {
            trackVisit: false
          };
          if (newMatches[3]) {
            opts.nearPost = newMatches[3];
          }
          topicController.get('content').loadPosts(opts);
          return;
        }
      }
      // Be wary of looking up the router. In this case, we have links in our
      // HTML, say form compiled markdown posts, that need to be routed.
      router = Discourse.__container__.lookup('router:main');
      router.router.updateURL(path);
      return router.handleURL(path);
    },

    // The classes of buttons to show on a post
    postButtons: (function() {
      return Discourse.SiteSettings.post_menu.split("|").map(function(i) {
        return "" + (i.replace(/\+/, '').capitalize());
      });
    }).property('Discourse.SiteSettings.post_menu'),

    bindDOMEvents: function() {
      var $html, hasTouch,
        _this = this;
      $html = jQuery('html');

      /* Add the discourse touch event */
      hasTouch = false;
      if ($html.hasClass('touch')) {
        hasTouch = true;
      }
      if (Modernizr.prefixed("MaxTouchPoints", navigator) > 1) {
        hasTouch = true;
      }
      if (hasTouch) {
        $html.addClass('discourse-touch');
        this.touch = true;
        this.hasTouch = true;
      } else {
        $html.addClass('discourse-no-touch');
        this.touch = false;
      }
      jQuery('#main').on('click.discourse', '[data-not-implemented=true]', function(e) {
        e.preventDefault();
        alert(Em.String.i18n('not_implemented'));
        return false;
      });
      jQuery('#main').on('click.discourse', 'a', function(e) {
        var $currentTarget, href;
        if (e.isDefaultPrevented() || e.metaKey || e.ctrlKey) {
          return;
        }
        $currentTarget = jQuery(e.currentTarget);
        href = $currentTarget.attr('href');
        if (href === void 0) {
          return;
        }
        if (href === '#') {
          return;
        }
        if ($currentTarget.attr('target')) {
          return;
        }
        if ($currentTarget.data('auto-route')) {
          return;
        }
        if ($currentTarget.hasClass('lightbox')) {
          return;
        }
        if (href.indexOf("mailto:") === 0) {
          return;
        }
        if (href.match(/^http[s]?:\/\//i) && !href.match(new RegExp("^http:\\/\\/" + window.location.hostname, "i"))) {
          return;
        }
        e.preventDefault();
        _this.routeTo(href);
        return false;
      });
      return jQuery(window).focus(function() {
        _this.set('hasFocus', true);
        return _this.set('notify', false);
      }).blur(function() {
        return _this.set('hasFocus', false);
      });
    },
    logout: function() {
      var username,
        _this = this;
      username = this.get('currentUser.username');
      Discourse.KeyValueStore.abandonLocal();
      return jQuery.ajax("/session/" + username, {
        type: 'DELETE',
        success: function(result) {
          /* To keep lots of our variables unbound, we can handle a redirect on logging out.
          */
          return window.location.reload();
        }
      });
    },
    /* fancy probes in ember
    */

    insertProbes: function() {
      var topLevel;
      if (typeof console === "undefined" || console === null) {
        return;
      }
      topLevel = function(fn, name) {
        return window.probes.measure(fn, {
          name: name,
          before: function(data, owner, args) {
            if (owner) {
              return window.probes.clear();
            }
          },
          after: function(data, owner, args) {
            var ary, f, n, v, _ref;
            if (owner && data.time > 10) {
              f = function(name, data) {
                if (data && data.count) {
                  return "" + name + " - " + data.count + " calls " + ((data.time + 0.0).toFixed(2)) + "ms";
                }
              };
              if (console && console.group) {
                console.group(f(name, data));
              } else {
                console.log("");
                console.log(f(name, data));
              }
              ary = [];
              _ref = window.probes;
              for (n in _ref) {
                v = _ref[n];
                if (n === name || v.time < 1) {
                  continue;
                }
                ary.push({
                  k: n,
                  v: v
                });
              }
              ary.sortBy(function(item) {
                if (item.v && item.v.time) {
                  return -item.v.time;
                } else {
                  return 0;
                }
              }).each(function(item) {
                var output;
                if (output = f("" + item.k, item.v)) {
                  return console.log(output);
                }
              });
              if (typeof console !== "undefined" && console !== null) {
                if (typeof console.groupEnd === "function") {
                  console.groupEnd();
                }
              }
              return window.probes.clear();
            }
          }
        });
      };
      Ember.View.prototype.renderToBuffer = window.probes.measure(Ember.View.prototype.renderToBuffer, "renderToBuffer");
      Discourse.routeTo = topLevel(Discourse.routeTo, "Discourse.routeTo");
      Ember.run.end = topLevel(Ember.run.end, "Ember.run.end");
    },
    authenticationComplete: function(options) {
      // TODO, how to dispatch this to the view without the container?
      var loginView;
      loginView = Discourse.__container__.lookup('controller:modal').get('currentView');
      return loginView.authenticationComplete(options);
    },
    buildRoutes: function(builder) {
      var oldBuilder;
      oldBuilder = Discourse.routeBuilder;
      Discourse.routeBuilder = function() {
        if (oldBuilder) {
          oldBuilder.call(this);
        }
        return builder.call(this);
      }
    },
    start: function() {
      this.bindDOMEvents();
      Discourse.SiteSettings = PreloadStore.getStatic('siteSettings');
      Discourse.MessageBus.start();
      Discourse.KeyValueStore.init("discourse_", Discourse.MessageBus);
      Discourse.insertProbes();

      // subscribe to any site customizations that are loaded
      jQuery('link.custom-css').each(function() {
        var id, split, stylesheet,
          _this = this;
        split = this.href.split("/");
        id = split[split.length - 1].split(".css")[0];
        stylesheet = this;
        return Discourse.MessageBus.subscribe("/file-change/" + id, function(data) {
          var orig, sp;
          if (!jQuery(stylesheet).data('orig')) {
            jQuery(stylesheet).data('orig', stylesheet.href);
          }
          orig = jQuery(stylesheet).data('orig');
          sp = orig.split(".css?");
          stylesheet.href = sp[0] + ".css?" + data;
        });
      });
      jQuery('header.custom').each(function() {
        var header;
        header = jQuery(this);
        return Discourse.MessageBus.subscribe("/header-change/" + (jQuery(this).data('key')), function(data) {
          return header.html(data);
        });
      });

      // possibly move this to dev only
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
              return jQuery.each(Ember.View.views, function() {
                var _this = this;
                if (this.get('templateName') === templateName) {
                  this.set('templateName', 'empty');
                  this.rerender();
                  return Em.run.next(function() {
                    _this.set('templateName', templateName);
                    return _this.rerender();
                  });
                }
              });
            });
          } else {
            return jQuery('link').each(function() {
              if (this.href.match(me.name) && me.hash) {
                if (!jQuery(this).data('orig')) {
                  jQuery(this).data('orig', this.href);
                }
                this.href = jQuery(this).data('orig') + "&hash=" + me.hash;
              }
            });
          }
        });
      });
    }
  });

  window.Discourse.Router = Discourse.Router.reopen({
    location: 'discourse_location'
  });

  // since we have no jquery-rails these days, hook up csrf token
  csrf_token = jQuery('meta[name=csrf-token]').attr('content');

  jQuery.ajaxPrefilter(function(options, originalOptions, xhr) {
    if (!options.crossDomain) {
      xhr.setRequestHeader('X-CSRF-Token', csrf_token);
    }
  });

}).call(this);
