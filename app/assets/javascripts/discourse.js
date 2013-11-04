/*global Modernizr:true*/
/*global assetPath:true*/
/*global Favcount:true*/

/**
  The main Discourse Application

  @class Discourse
  @extends Ember.Application
**/
Discourse = Ember.Application.createWithMixins(Discourse.Ajax, {
  rootElement: '#main',

  // Whether the app has focus or not
  hasFocus: true,

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

  Resolver: Discourse.Resolver,

  titleChanged: function() {
    var title = "";
    if (this.get('title')) {
      title += "" + (this.get('title')) + " - ";
    }
    title += Discourse.SiteSettings.title;
    $('title').text(title);

    var notifyCount = this.get('notifyCount');
    if (notifyCount > 0 && !Discourse.User.currentProp('dynamic_favicon')) {
      title = "(" + notifyCount + ") " + title;
    }
    // chrome bug workaround see: http://stackoverflow.com/questions/2952384/changing-the-window-title-when-focussing-the-window-doesnt-work-in-chrome
    window.setTimeout(function() {
      document.title = ".";
      document.title = title;
    }, 200);
  }.observes('title', 'hasFocus', 'notifyCount'),

  faviconChanged: function() {
    if(Discourse.User.currentProp('dynamic_favicon')) {
      new Favcount(Discourse.SiteSettings.favicon_url).set(
        this.get('notifyCount')
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
      alert(I18n.t('not_implemented'));
      return false;
    });

    $('#main').on('click.discourse', 'a', function(e) {
      if (e.isDefaultPrevented() || e.shiftKey || e.metaKey || e.ctrlKey) { return; }

      var $currentTarget = $(e.currentTarget),
          href = $currentTarget.attr('href');

      if (!href ||
          href === '#' ||
          $currentTarget.attr('target') ||
          $currentTarget.data('ember-action') ||
          $currentTarget.data('auto-route') ||
          $currentTarget.hasClass('ember-view') ||
          $currentTarget.hasClass('lightbox') ||
          href.indexOf("mailto:") === 0 ||
          (href.match(/^http[s]?:\/\//i) && !href.match(new RegExp("^http:\\/\\/" + window.location.hostname, "i")))) {
         return;
      }

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
    Discourse.csrfToken = $('meta[name=csrf-token]').attr('content');

    $.ajaxPrefilter(function(options, originalOptions, xhr) {
      if (!options.crossDomain) {
        xhr.setRequestHeader('X-CSRF-Token', Discourse.csrfToken);
      }
    });

    bootbox.animate(false);
    bootbox.backdrop(true); // clicking outside a bootbox modal closes it

    Discourse.Mobile.init();

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
      window.location.pathname = Discourse.getURL('/');
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
        var site = Discourse.Site.current();
        _.each(data.categories,function(c){
          site.updateCategory(c);
        });
      });

    }
  },

  /**
    Add an initializer hook for after the Discourse Application starts up.

    @method addInitializer
    @param {Function} init the initializer to add.
  **/
  addInitializer: function(init) {
    Discourse.initializers = Discourse.initializers || [];
    Discourse.initializers.push(init);
  },

  /**
    Start up the Discourse application.

    @method start
  **/
  start: function() {
    Discourse.bindDOMEvents();
    Discourse.MessageBus.alwaysLongPoll = Discourse.Environment === "development";
    Discourse.MessageBus.start();
    Discourse.KeyValueStore.init("discourse_", Discourse.MessageBus);

    // Developer specific functions
    Discourse.Development.observeLiveChanges();
    Discourse.subscribeUserToNotifications();

    if (Discourse.initializers) {
      var self = this;
      Em.run.next(function() {
        Discourse.initializers.forEach(function (init) {
          init.call(self);
        });
      });
    }
  }

});

Discourse.Router = Discourse.Router.reopen({ location: 'discourse_location' });
