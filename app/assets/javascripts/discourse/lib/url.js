/**
  URL related functions.

  @class URL
  @namespace Discourse
  @module Discourse
**/
Discourse.URL = Em.Object.createWithMixins({

  // Used for matching a topic
  TOPIC_REGEXP: /\/t\/([^\/]+)\/(\d+)\/?(\d+)?/,

  // Used for matching a /more URL
  MORE_REGEXP: /\/more$/,

  /**
    Browser aware replaceState. Will only be invoked if the browser supports it.

    @method replaceState
    @param {String} path The path we are replacing our history state with.
  **/
  replaceState: function(path) {

    if (window.history &&
        window.history.pushState &&
        window.history.replaceState &&
        !navigator.userAgent.match(/((iPod|iPhone|iPad).+\bOS\s+[1-4]|WebApps\/.+CFNetwork)/) &&
        (window.location.pathname !== path)) {

        // Always use replaceState in the next runloop to prevent weird routes changing
        // while URLs are loading. For example, while a topic loads it sets `currentPost`
        // which triggers a replaceState even though the topic hasn't fully loaded yet!
        Em.run.next(function() {
          var location = Discourse.URL.get('router.location');
          if (location.replaceURL) { location.replaceURL(path); }
        });
    }
  },

  /**
    Our custom routeTo method is used to intelligently overwrite default routing
    behavior.

    It contains the logic necessary to route within a topic using replaceState to
    keep the history intact.

    @method routeTo
    @param {String} path The path we are routing to.
  **/
  routeTo: function(path) {

    var oldPath = window.location.pathname;
    path = path.replace(/https?\:\/\/[^\/]+/, '');

    // If the URL is absolute, remove rootURL
    if (path.match(/^\//)) {
      var rootURL = (Discourse.BaseUri === undefined ? "/" : Discourse.BaseUri);
      rootURL = rootURL.replace(/\/$/, '');
      path = path.replace(rootURL, '');
    }

    // TODO: Extract into rules we can inject into the URL handler
    if (this.navigatedToHome(oldPath, path)) { return; }
    if (this.navigatedToListMore(oldPath, path)) { return; }
    if (this.navigatedToPost(oldPath, path)) { return; }

    if (path.match(/^\/?users\/[^\/]+$/)) {
      path += "/activity";
    }
    // Be wary of looking up the router. In this case, we have links in our
    // HTML, say form compiled markdown posts, that need to be routed.
    var router = this.get('router');
    router.router.updateURL(path);
    return router.handleURL(path);
  },

  /**
    Replaces the query parameters in the URL. Use no parameters to clear them.

    @method replaceQueryParams
  **/
  queryParams: Em.computed.alias('router.location.queryParams'),

  /**
    Redirect to a URL.
    This has been extracted so it can be tested.

    @method redirectTo
  **/
  redirectTo: function(url) {
    window.location = Discourse.getURL(url);
  },

  /**
    @private

    If we're viewing more topics, scroll to where we were previously.

    @method navigatedToListMore
    @param {String} oldPath the previous path we were on
    @param {String} path the path we're navigating to
  **/
  navigatedToListMore: function(oldPath, path) {
    // If we transition from a /more path, scroll to the top
    if (this.MORE_REGEXP.exec(oldPath) && (oldPath.indexOf(path) === 0)) {
      window.scrollTo(0, 0);
    }
    return false;
  },

  /**
    @private

    If the URL is in the topic form, /t/something/:topic_id/:post_number
    then we want to apply some special logic. If the post_number changes within the
    same topic, use replaceState and instruct our controller to load more posts.

    @method navigatedToPost
    @param {String} oldPath the previous path we were on
    @param {String} path the path we're navigating to
  **/
  navigatedToPost: function(oldPath, path) {

    var newMatches = this.TOPIC_REGEXP.exec(path),
        newTopicId = newMatches ? newMatches[2] : null;

    if (newTopicId) {
      var oldMatches = this.TOPIC_REGEXP.exec(oldPath),
          oldTopicId = oldMatches ? oldMatches[2] : null;

      // If the topic_id is the same
      if (oldTopicId === newTopicId) {
        Discourse.URL.replaceState(path);

        var topicController = Discourse.__container__.lookup('controller:topic'),
            opts = {};

        if (newMatches[3]) opts.nearPost = newMatches[3];
        var postStream = topicController.get('postStream');
        postStream.refresh(opts).then(function() {
          topicController.setProperties({
            currentPost: opts.nearPost || 1,
            progressPosition: opts.nearPost || 1
          });
        });

        // Abort routing, we have replaced our state.
        return true;
      }
      this.set('queryParams', null);
    }

    return false;
  },

  /**
    @private

    Handle the custom case of routing to the root path from itself.

    @param {String} oldPath the previous path we were on
    @param {String} path the path we're navigating to
  **/
  navigatedToHome: function(oldPath, path) {

    var defaultFilter = "/" + Discourse.ListController.filters[0];

    if (path === "/" && (oldPath === "/" || oldPath === defaultFilter)) {
      // Refresh our list
      this.controllerFor('list').refresh();
      return true;
    }

    return false;
  },

  /**
    @private

    Get the origin of the current location.
    This has been extracted so it can be tested.

    @method origin
  **/
  origin: function() {
    return window.location.origin;
  },

  /**
    @private

    Get a handle on the application's router. Note that currently it uses `__container__` which is not
    advised but there is no other way to access the router.

    @property router
  **/
  router: function() {
    return Discourse.__container__.lookup('router:main');
  }.property(),

  /**
    @private

    Get a controller. Note that currently it uses `__container__` which is not
    advised but there is no other way to access the router.

    @method controllerFor
    @param {String} name the name of the controller
  **/
  controllerFor: function(name) {
    return Discourse.__container__.lookup('controller:' + name);
  }


});
