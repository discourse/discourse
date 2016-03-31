/**
@module Discourse
*/

const get = Ember.get, set = Ember.set;
let popstateFired = false;
const supportsHistoryState = window.history && 'state' in window.history;

const popstateCallbacks = [];

/**
  `Ember.DiscourseLocation` implements the location API using the browser's
  `history.pushState` API.

  @class DiscourseLocation
  @namespace Discourse
  @extends Ember.Object
*/
const DiscourseLocation = Ember.Object.extend({

  init() {
    set(this, 'location', get(this, 'location') || window.location);
    this.initState();
  },

  /**
    @private

    Used to set state on first call to setURL

    @method initState
  */
  initState() {
    const history = get(this, 'history') || window.history;
    if (history && history.scrollRestoration) {
      history.scrollRestoration = "manual";
    }

    set(this, 'history', history);

    let url = this.formatURL(this.getURL());
    const loc = get(this, 'location');

    if (loc && loc.hash) {
      url += loc.hash;
    }

    this.replaceState(url);
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
  getURL() {
    const location = get(this, 'location');
    let url = location.pathname;

    url = url.replace(Discourse.BaseUri, '');

    const search = location.search || '';
    url += search;

    return url;
  },

  /**
    @private

    Uses `history.pushState` to update the url without a page reload.

    @method setURL
    @param path {String}
  */
  setURL(path) {
    const state = this.getState();
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
  replaceURL(path) {
    const state = this.getState();
    path = this.formatURL(path);

    if (state && state.path !== path) {
      this.replaceState(path);
    }
  },

  /**
   @private

   Get the current `history.state`
   Polyfill checks for native browser support and falls back to retrieving
   from a private _historyState constiable

   @method getState
  */
  getState() {
    return supportsHistoryState ? get(this, 'history').state : this._historyState;
  },

  /**
   @private

   Pushes a new state

   @method pushState
   @param path {String}
  */
  pushState(path) {
    const state = { path: path };

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
  replaceState(path) {
    const state = { path: path };

    // store state if browser doesn't support `history.state`
    if (!supportsHistoryState) {
      this._historyState = state;
    } else {
      get(this, 'history').replaceState(state, null, path);
    }

    // used for webkit workaround
    this._previousURL = this.getURL();
  },

  /**
    @private

    Register a callback to be invoked whenever the browser
    history changes, including using forward and back buttons.

    @method onUpdateURL
    @param callback {Function}
  */
  onUpdateURL(callback) {
    const guid = Ember.guidFor(this),
        self = this;

    Ember.$(window).on('popstate.ember-location-'+guid, function() {
      // Ignore initial page load popstate event in Chrome
      if (!popstateFired) {
        popstateFired = true;
        if (self.getURL() === self._previousURL) { return; }
      }
      const url = self.getURL();
      popstateCallbacks.forEach(function(cb) {
        cb(url);
      });
      callback(url);
    });
  },

  /**
    @private

    Used when using `{{action}}` helper.  The url is always appended to the rootURL.

    @method formatURL
    @param url {String}
  */
  formatURL(url) {
    let rootURL = get(this, 'rootURL');

    if (url !== '') {
      rootURL = rootURL.replace(/\/$/, '');

      if (rootURL.length > 0 && url.indexOf(rootURL + "/") === 0){
        rootURL = "";
      }
    }

    return rootURL + url;
  },

  willDestroy() {
    const guid = Ember.guidFor(this);

    Ember.$(window).off('popstate.ember-location-'+guid);
  }

});

export default DiscourseLocation;
