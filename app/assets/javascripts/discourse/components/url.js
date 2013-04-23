/**
  URL related functions.

  @class URL
  @namespace Discourse
  @module Discourse
**/
Discourse.URL = {

  // Used for matching a topic
  TOPIC_REGEXP: /\/t\/([^\/]+)\/(\d+)\/?(\d+)?/,

  // Used for matching a /more URL
  MORE_REGEXP: /\/more$/,

  /**
    @private

    Get a handle on the application's router. Note that currently it uses `__container__` which is not
    advised but there is no other way to access the router.

    @method router
  **/
  router: function() {
    return Discourse.__container__.lookup('router:main');
  },

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
          Discourse.URL.router().get('location').replaceURL(path);
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
    /*
      If the URL is absolute, remove rootURL
     */
    if (path.match(/^\//)) {
      var rootURL = (Discourse.BaseUri === undefined ? "/" : Discourse.BaseUri);
      rootURL = rootURL.replace(/\/$/, '');
      path = path.replace(rootURL, '');
    }

    /*
      If the URL is in the topic form, /t/something/:topic_id/:post_number
      then we want to apply some special logic. If the post_number changes within the
      same topic, use replaceState and instruct our controller to load more posts.
    */
    var newMatches = this.TOPIC_REGEXP.exec(path);
    var newTopicId = newMatches ? newMatches[2] : null;
    if (newTopicId) {
      var oldMatches = this.TOPIC_REGEXP.exec(oldPath);
      var oldTopicId = oldMatches ? oldMatches[2] : null;

      // If the topic_id is the same
      if (oldTopicId === newTopicId) {
        Discourse.URL.replaceState(path);
        var topicController = Discourse.__container__.lookup('controller:topic');
        var opts = { trackVisit: false };
        if (newMatches[3]) opts.nearPost = newMatches[3];
        topicController.cancelFilter();
        topicController.loadPosts(opts);

        // Abort routing, we have replaced our state.
        return;
      }
    }

    // If we transition from a /more path, scroll to the top
    if (this.MORE_REGEXP.exec(oldPath) && (oldPath.indexOf(path) === 0)) {
      window.scrollTo(0, 0);
    }

    // Be wary of looking up the router. In this case, we have links in our
    // HTML, say form compiled markdown posts, that need to be routed.
    var router = this.router();
    router.router.updateURL(path);
    return router.handleURL(path);
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

    Redirect to a URL.
    This has been extracted so it can be tested.

    @method redirectTo
  **/
  redirectTo: function(url) {
    window.location = url;
  }

};
