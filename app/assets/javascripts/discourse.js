/*global Modernizr:true*/
/*global assetPath:true*/

/**
  The main Discourse Application

  @class Discourse
  @extends Ember.Application
**/
Discourse = Ember.Application.createWithMixins({
  rootElement: '#main',

  // Data we want to remember for a short period
  transient: Em.Object.create(),

  // Whether the app has focus or not
  hasFocus: true,

  // Are we currently scrolling?
  scrolling: false,

  // The highest seen post number by topic
  highestSeenByTopic: {},

  // Helps with integration tests
  URL_FIXTURES: {},

  getURL: function(url) {

    // If it's a non relative URL, return it.
    if (url.indexOf('http') === 0) return url;

    var u = (Discourse.BaseUri === undefined ? "/" : Discourse.BaseUri);
    if (u[u.length-1] === '/') {
      u = u.substring(0, u.length-1);
    }
    return u + url;
  },

  /**
    This custom resolver allows us to find admin templates without calling .render
    even though our path formats are slightly different than what ember prefers.
  */
  resolver: Ember.DefaultResolver.extend({

    resolveTemplate: function(parsedName) {
      var resolvedTemplate = this._super(parsedName);
      if (resolvedTemplate) { return resolvedTemplate; }

      var decamelized = parsedName.fullNameWithoutType.decamelize();

      // See if we can find it with slashes instead of underscores
      var slashed = decamelized.replace("_", "/");
      resolvedTemplate = Ember.TEMPLATES[slashed];
      if (resolvedTemplate) { return resolvedTemplate; }

      // If we can't find a template, check to see if it's similar to how discourse
      // lays out templates like: adminEmail => admin/templates/email
      if (parsedName.fullNameWithoutType.indexOf('admin') === 0) {
        decamelized = decamelized.replace(/^admin\_/, 'admin/templates/');
        decamelized = decamelized.replace(/^admin\./, 'admin/templates/');
        decamelized = decamelized.replace(/\./, '_');

        resolvedTemplate = Ember.TEMPLATES[decamelized];
        if (resolvedTemplate) { return resolvedTemplate; }
      }
      return Ember.TEMPLATES.not_found;
    }
  }),

  titleChanged: function() {
    var title;
    title = "";
    if (this.get('title')) {
      title += "" + (this.get('title')) + " - ";
    }
    title += Discourse.SiteSettings.title;
    $('title').text(title);

    var notifyCount = this.get('notifyCount');
    if (notifyCount > 0 && !Discourse.User.current('dynamic_favicon')) {
      title = "(" + notifyCount + ") " + title;
    }
    // chrome bug workaround see: http://stackoverflow.com/questions/2952384/changing-the-window-title-when-focussing-the-window-doesnt-work-in-chrome
    window.setTimeout(function() {
      document.title = ".";
      document.title = title;
    }, 200);
  }.observes('title', 'hasFocus', 'notifyCount'),

  faviconChanged: function() {
    if(Discourse.User.current('dynamic_favicon')) {
      $.faviconNotify(
        Discourse.SiteSettings.favicon_url, this.get('notifyCount')
      );
    }
  }.observes('notifyCount'),

  // The classes of buttons to show on a post
  postButtons: function() {
    return Discourse.SiteSettings.post_menu.split("|").map(function(i) {
      return (i.replace(/\+/, '').capitalize());
    });
  }.property('Discourse.SiteSettings.post_menu'),

  notifyTitle: function(count) {
    this.set('notifyCount', count);
  },

  openComposer: function(opts) {
    // TODO, remove container link
    var composer = Discourse.__container__.lookup('controller:composer');
    if (composer) composer.open(opts);
  },

  /**
    Establishes global DOM events and bindings via jQuery.

    @method bindDOMEvents
  **/
  bindDOMEvents: function() {
    var $html, hasTouch;

    $html = $('html');
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

    $('#main').on('click.discourse', '[data-not-implemented=true]', function(e) {
      e.preventDefault();
      alert(Em.String.i18n('not_implemented'));
      return false;
    });

    $('#main').on('click.discourse', 'a', function(e) {
      if (e.isDefaultPrevented() || e.shiftKey || e.metaKey || e.ctrlKey) return;

      var $currentTarget = $(e.currentTarget);
      var href = $currentTarget.attr('href');
      if (!href) return;
      if (href === '#') return;
      if ($currentTarget.attr('target')) return;
      if ($currentTarget.data('auto-route')) return;

      // If it's an ember #linkTo skip it
      if ($currentTarget.hasClass('ember-view')) return;

      if ($currentTarget.hasClass('lightbox')) return;
      if (href.indexOf("mailto:") === 0) return;
      if (href.match(/^http[s]?:\/\//i) && !href.match(new RegExp("^http:\\/\\/" + window.location.hostname, "i"))) return;

      e.preventDefault();
      Discourse.URL.routeTo(href);
      return false;
    });

    $(window).focus(function() {
      Discourse.set('hasFocus', true);
      Discourse.set('notify', false);
    }).blur(function() {
      Discourse.set('hasFocus', false);
    });

    // Add a CSRF token to all AJAX requests
    var csrfToken = $('meta[name=csrf-token]').attr('content');
    $.ajaxPrefilter(function(options, originalOptions, xhr) {
      if (!options.crossDomain) {
        xhr.setRequestHeader('X-CSRF-Token', csrfToken);
      }
    });

    bootbox.animate(false);
    bootbox.backdrop(true); // clicking outside a bootbox modal closes it

    setInterval(function(){
      Discourse.Formatter.updateRelativeAge($('.relative-date'));
    },60 * 1000);
  },

  /**
    Log the current user out of Discourse

    @method logout
  **/
  logout: function() {
    Discourse.User.logout().then(function() {
      // Reloading will refresh unbound properties
      Discourse.KeyValueStore.abandonLocal();
      window.location.reload();
    });
  },

  authenticationComplete: function(options) {
    // TODO, how to dispatch this to the controller without the container?
    var loginController = Discourse.__container__.lookup('controller:login');
    return loginController.authenticationComplete(options);
  },

  loginRequired: function() {
    return (
      Discourse.SiteSettings.login_required && !Discourse.User.current()
    );
  }.property(),

  redirectIfLoginRequired: function(route) {
    if(this.get('loginRequired')) { route.transitionTo('login'); }
  },

  /**
    Our own $.ajax method. Makes sure the .then method executes in an Ember runloop
    for performance reasons. Also automatically adjusts the URL to support installs
    in subfolders.

    @method ajax
  **/
  ajax: function() {

    var url, args;

    if (arguments.length === 1) {
      if (typeof arguments[0] === "string") {
        url = arguments[0];
        args = {};
      } else {
        args = arguments[0];
        url = args.url;
        delete args.url;
      }
    } else if (arguments.length === 2) {
      url = arguments[0];
      args = arguments[1];
    }

    if (args.success) {
      console.warning("DEPRECATION: Discourse.ajax should use promises, received 'success' callback");
    }
    if (args.error) {
      console.warning("DEPRECATION: Discourse.ajax should use promises, received 'error' callback");
    }

    // If we have URL_FIXTURES, load from there instead (testing)
    var fixture = Discourse.URL_FIXTURES && Discourse.URL_FIXTURES[url];
    if (fixture) {
      return Ember.Deferred.promise(function(promise) {
        promise.resolve(fixture);
      });
    }

    return Ember.Deferred.promise(function (promise) {
      var oldSuccess = args.success;
      args.success = function(xhr) {
        Ember.run(promise, promise.resolve, xhr);
        if (oldSuccess) oldSuccess(xhr);
      };

      var oldError = args.error;
      args.error = function(xhr) {

        // If it's a parseerror, don't reject
        if (xhr.status === 200) return args.success(xhr);

        promise.reject(xhr);
        if (oldError) oldError(xhr);
      };

      // We default to JSON on GET. If we don't, sometimes if the server doesn't return the proper header
      // it will not be parsed as an object.
      if (!args.type) args.type = 'GET';
      if ((!args.dataType) && (args.type === 'GET')) args.dataType = 'json';

      $.ajax(Discourse.getURL(url), args);
    });
  },


  /**
    Subscribes the current user to receive message bus notifications
  **/
  subscribeUserToNotifications: function() {
    var user = Discourse.User.current();
    if (user) {
      var bus = Discourse.MessageBus;
      bus.callbackInterval = Discourse.SiteSettings.polling_interval;
      bus.enableLongPolling = true;
      if (user.admin || user.moderator) {
        bus.subscribe("/flagged_counts", function(data) {
          user.set('site_flagged_posts_count', data.total);
        });
      }
      bus.subscribe("/notification/" + user.get('id'), (function(data) {
        user.set('unread_notifications', data.unread_notifications);
        user.set('unread_private_messages', data.unread_private_messages);
      }), user.notification_channel_position);

      bus.subscribe("/categories", function(data){
        var site = Discourse.Site.instance();
        _.each(data.categories,function(c){
          site.updateCategory(c);
        });
      });

    }
  },



  /**
    Start up the Discourse application.

    @method start
  **/
  start: function() {
    Discourse.bindDOMEvents();
    Discourse.SiteSettings = PreloadStore.get('siteSettings');
    Discourse.MessageBus.alwaysLongPoll = Discourse.Environment === "development";
    Discourse.MessageBus.start();
    Discourse.KeyValueStore.init("discourse_", Discourse.MessageBus);

    // Developer specific functions
    Discourse.Development.setupProbes();
    Discourse.Development.observeLiveChanges();
    Discourse.subscribeUserToNotifications();
  }

});

Discourse.Router = Discourse.Router.reopen({ location: 'discourse_location' });
