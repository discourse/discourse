/*global historyState:true */

/**
@module Discourse
*/

var get = Ember.get, set = Ember.set;
var popstateReady = false;

// Thanks: https://gist.github.com/kares/956897
var re = /([^&=]+)=?([^&]*)/g;
var decode = function(str) {
    return decodeURIComponent(str.replace(/\+/g, ' '));
};
$.parseParams = function(query) {
    var params = {}, e;
    if (query) {
        if (query.substr(0, 1) === '?') {
            query = query.substr(1);
        }

        while (e = re.exec(query)) {
            var k = decode(e[1]);
            var v = decode(e[2]);
            if (params[k] !== undefined) {
                if (!$.isArray(params[k])) {
                    params[k] = [params[k]];
                }
                params[k].push(v);
            } else {
                params[k] = v;
            }
        }
    }
    return params;
};


/**
  `Ember.DiscourseLocation` implements the location API using the browser's
  `history.pushState` API.

  @class DiscourseLocation
  @namespace Discourse
  @extends Ember.Object
*/
Ember.DiscourseLocation = Ember.Object.extend({

  init: function() {
    set(this, 'location', get(this, 'location') || window.location);
    if ( $.inArray('state', $.event.props) < 0 ) {
      jQuery.event.props.push('state');
    }
    this.initState();
  },

  /**
    @private

    Used to set state on first call to setURL

    @method initState
  */
  initState: function() {

    var location = this.get('location');
    if (location && location.search) {
      this.set('queryParams', $.parseParams(location.search));
    }

    this.replaceState(this.formatURL(this.getURL()));
    set(this, 'history', window.history);
  },

  /**
    @private

    Returns the current `location.pathname` without rootURL

    @method getURL
  */
  getURL: function() {
    var rootURL = (Discourse.BaseUri === undefined ? "/" : Discourse.BaseUri),
        url = get(this, 'location').pathname;

    rootURL = rootURL.replace(/\/$/, '');
    url = url.replace(rootURL, '');

    return url;
  },

  /**
    @private

    Uses `history.pushState` to update the url without a page reload.

    @method setURL
    @param path {String}
  */
  setURL: function(path) {

    path = this.formatURL(path);
    if (this.getState() && this.getState().path !== path) {
      popstateReady = true;
      this.pushState(path);
    }
  },

  /**
    @private

    Uses `history.replaceState` to update the url without a page reload
    or history modification.

    @method replaceURL
    @param path {String}
  */
  replaceURL: function(path) {

    path = this.formatURL(path);

    if (this.getState() && this.getState().path !== path) {
      popstateReady = true;
      this.replaceState(path);
    }
  },

  /**
   @private

   Get the current `history.state`

   @method getState
  */
  getState: function() {
    historyState = get(this, 'history').state;
    if (historyState) return historyState;

    return {path: window.location.pathname};
  },

  /**
   @private

   Pushes a new state

   @method pushState
   @param path {String}
  */
  pushState: function(path) {
    if (!window.history.pushState) return;
    this.set('currentState', { path: path } );
    window.history.pushState({ path: path }, null, path);
  },

  /**
   @private

   Replaces the current state

   @method replaceState
   @param path {String}
  */
  replaceState: function(path) {
    if (!window.history.replaceState) return;
    this.set('currentState', { path: path } );
    window.history.replaceState({ path: path }, null, path);
  },


  queryParamsString: function() {
    var params = this.get('queryParams');
    if (Em.isEmpty(params) || Em.isEmpty(Object.keys(params))) {
      return "";
    } else {
      return "?" + $.param(params).replace(/%5B/g, "[").replace(/%5D/g, "]");
    }
  }.property('queryParams'),

  // When our query params change, update the URL
  queryParamsStringChanged: function() {
    this.replaceState(this.formatURL(this.getURL()));
  }.observes('queryParamsString'),

  /**
    @private

    Register a callback to be invoked whenever the browser
    history changes, including using forward and back buttons.

    @method onUpdateURL
    @param callback {Function}
  */
  onUpdateURL: function(callback) {
    var guid = Ember.guidFor(this),
        self = this;

    $(window).bind('popstate.ember-location-'+guid, function(e) {
      if (e.state) {
        var currentState = self.get('currentState');
        if (currentState) {
          var url = e.state.path,
              rootURL = (Discourse.BaseUri === undefined ? "/" : Discourse.BaseUri);

          rootURL = rootURL.replace(/\/$/, '');
          url = url.replace(rootURL, '');
          callback(url);
        } else {
          this.set('currentState', e.state);
        }
      }

    });
  },

  /**
    @private

    Used when using `{{action}}` helper.  The url is always appended to the rootURL.

    @method formatURL
    @param url {String}
  */
  formatURL: function(url) {
    var rootURL = (Discourse.BaseUri === undefined ? "/" : Discourse.BaseUri);

    if (url !== '') {
      rootURL = rootURL.replace(/\/$/, '');
    }

    // remove prefix from URL if it is already in url - i.e. /discourse/t/... -> /t/if rootURL is /discourse
    // this sometimes happens when navigating to already visited location
    if ((rootURL.length > 1) && (url.substring(0, rootURL.length + 1) === (rootURL + "/")))
    {
      url = url.substring(rootURL.length);
    }

    return rootURL + url + this.get('queryParamsString');
  },

  willDestroy: function() {
    var guid = Ember.guidFor(this);

    Ember.$(window).unbind('popstate.ember-location-'+guid);
  }
});

Ember.Location.registerImplementation('discourse_location', Ember.DiscourseLocation);
