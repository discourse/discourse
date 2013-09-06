/**
@module Discourse
*/

var get = Ember.get, set = Ember.set;
var popstateFired = false;
var supportsHistoryState = window.history && 'state' in window.history;

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

    set(this, 'history', get(this, 'history') || window.history);
    this.replaceState(this.formatURL(this.getURL()));
  },

  /**
    Will be pre-pended to path upon state change

    @property rootURL
    @default '/'
  */
  rootURL: '/',

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
    var state = this.getState();
    path = this.formatURL(path);

    if (state && state.path !== path) {
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
    var state = this.getState();
    path = this.formatURL(path);

    if (state && state.path !== path) {
      this.replaceState(path);
    }
  },

  /**
   @private

   Get the current `history.state`
   Polyfill checks for native browser support and falls back to retrieving
   from a private _historyState variable

   @method getState
  */
  getState: function() {
    return supportsHistoryState ? get(this, 'history').state : this._historyState;
  },

  /**
   @private

   Pushes a new state

   @method pushState
   @param path {String}
  */
  pushState: function(path) {
    var state = { path: path };

    // store state if browser doesn't support `history.state`
    if (!supportsHistoryState) {
      this._historyState = state;
    } else {
      get(this, 'history').pushState(state, null, path);
    }

    // used for webkit workaround
    this._previousURL = this.getURL();
  },

  /**
   @private

   Replaces the current state

   @method replaceState
   @param path {String}
  */
  replaceState: function(path) {
    var state = { path: path };

    // store state if browser doesn't support `history.state`
    if (!supportsHistoryState) {
      this._historyState = state;
    } else {
      get(this, 'history').replaceState(state, null, path);
    }

    // used for webkit workaround
    this._previousURL = this.getURL();
  },


  queryParamsString: function() {
    var params = this.get('queryParams');
    if (Em.isEmpty(params) || Em.isEmpty(Object.keys(params))) {
      return "";
    } else {
      return "?" + decodeURIComponent($.param(params, true));
    }
  }.property('queryParams'),

  // When our query params change, update the URL
  queryParamsStringChanged: function() {
    var loc = this;
    Em.run.next(function () {
      loc.replaceState(loc.formatURL(loc.getURL()));
    });
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

    Ember.$(window).on('popstate.ember-location-'+guid, function(e) {
      // Ignore initial page load popstate event in Chrome
      if (!popstateFired) {
        popstateFired = true;
        if (self.getURL() === self._previousURL) { return; }
      }
      callback(self.getURL());
    });
  },

  /**
    @private

    Used when using `{{action}}` helper.  The url is always appended to the rootURL.

    @method formatURL
    @param url {String}
  */
  formatURL: function(url) {
    var rootURL = get(this, 'rootURL');

    if (url !== '') {
      rootURL = rootURL.replace(/\/$/, '');
    }

    return rootURL + url + this.get('queryParamsString');
  },

  willDestroy: function() {
    var guid = Ember.guidFor(this);

    Ember.$(window).off('popstate.ember-location-'+guid);
  }

});

Ember.Location.registerImplementation('discourse_location', Ember.DiscourseLocation);
