/**
  URL related functions.

  @class URL
  @namespace Discourse
  @module Discourse
**/
Discourse.URL = {

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
        return history.replaceState({ path: path }, null, path);
    }
  },

  /**
    Our custom routeTo method is used to intelligently overwrite default routing
    behavior.

    It contains the logic necessary to route within a topic using replaceState to
    keep the history intact.

    Note that currently it uses `__container__` which is not advised
    but there is no other way to access the router.

    @method routeTo
    @param {String} path The path we are routing to.
  **/
  routeTo: function(path) {
    var newMatches, newTopicId, oldMatches, oldTopicId, opts, router, topicController, topicRegexp;
    path = path.replace(/https?\:\/\/[^\/]+/, '');

    console.log("route to: " + path);

    // If we're in the same topic, don't push the state
    topicRegexp = /\/t\/([^\/]+)\/(\d+)\/?(\d+)?/;
    newMatches = topicRegexp.exec(path);
    newTopicId = newMatches ? newMatches[2] : null;
    if (newTopicId) {
      oldMatches = topicRegexp.exec(window.location.pathname);
      if ((oldTopicId = oldMatches ? oldMatches[2] : void 0) && (oldTopicId === newTopicId)) {
        Discourse.URL.replaceState(path);
        topicController = Discourse.__container__.lookup('controller:topic');
        opts = { trackVisit: false };
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
  }

};