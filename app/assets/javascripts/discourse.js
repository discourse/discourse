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

  getURL: function(url) {
    var u = (Discourse.BaseUri === undefined ? "/" : Discourse.BaseUri);
    if (u[u.length-1] === '/') {
      u = u.substring(0, u.length-1);
    }
    return u + url;
  },

  titleChanged: function() {
    var title;
    title = "";
    if (this.get('title')) {
      title += "" + (this.get('title')) + " - ";
    }
    title += Discourse.SiteSettings.title;
    $('title').text(title);
    if (!this.get('hasFocus') && this.get('notify')) {
      title = "(*) " + title;
    }
    // chrome bug workaround see: http://stackoverflow.com/questions/2952384/changing-the-window-title-when-focussing-the-window-doesnt-work-in-chrome
    window.setTimeout(function() {
      document.title = ".";
      document.title = title;
    }, 200);
  }.observes('title', 'hasFocus', 'notify'),

  currentUserChanged: function() {

    // We don't want to receive any previous user notifications
    var bus = Discourse.MessageBus;
    bus.unsubscribe("/notification/*");
    bus.callbackInterval = Discourse.SiteSettings.anon_polling_interval;
    bus.enableLongPolling = false;

    var user = this.get('currentUser');
    if (user) {
      bus.callbackInterval = Discourse.SiteSettings.polling_interval;
      bus.enableLongPolling = true;
      if (user.admin) {
        bus.subscribe("/flagged_counts", function(data) {
          user.set('site_flagged_posts_count', data.total);
        });
      }
      bus.subscribe("/notification/" + user.id, (function(data) {
        user.set('unread_notifications', data.unread_notifications);
        user.set('unread_private_messages', data.unread_private_messages);
      }), user.notification_channel_position);
      bus.subscribe("/categories", function(data){
        Discourse.get('site').set('categories', data.categories.map(function(c){
          return Discourse.Category.create(c);
        }));
      });
    }
  }.observes('currentUser'),

  // The classes of buttons to show on a post
  postButtons: function() {
    return Discourse.SiteSettings.post_menu.split("|").map(function(i) {
      return (i.replace(/\+/, '').capitalize());
    });
  }.property('Discourse.SiteSettings.post_menu'),

  notifyTitle: function() {
    this.set('notify', true);
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
  },

  /**
    Log the current user out of Discourse

    @method logout
  **/
  logout: function() {
    Discourse.KeyValueStore.abandonLocal();
    Discourse.ajax(Discourse.getURL("/session/") + this.get('currentUser.username'), {
      type: 'DELETE'
    }).then(function() {
      // Reloading will refresh unbound properties
      window.location.reload();
    });
  },

  authenticationComplete: function(options) {
    // TODO, how to dispatch this to the view without the container?
    var loginView = Discourse.__container__.lookup('controller:modal').get('currentView');
    return loginView.authenticationComplete(options);
  },

  /**
    Our own $.ajax method. Makes sure the .then method executes in an Ember runloop
    for performance reasons.

    @method ajax
  **/
  ajax: function() {
    return $.ajax.apply(this, arguments);
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
    // Make sure we delete preloaded data
    PreloadStore.remove('siteSettings');
    // Developer specific functions
    Discourse.Development.setupProbes();
    Discourse.Development.observeLiveChanges();
  }

});

Discourse.Router = Discourse.Router.reopen({ location: 'discourse_location' });
