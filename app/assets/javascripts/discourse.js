/*global Favcount:true*/
var DiscourseResolver = require('discourse/ember/resolver').default;

// Allow us to import Ember
define('ember', ['exports'], function(__exports__) {
  __exports__["default"] = Ember;
});

window.Discourse = Ember.Application.createWithMixins(Discourse.Ajax, {
  rootElement: '#main',
  _docTitle: document.title,

  getURL: function(url) {
    if (!url) return url;

    // if it's a non relative URL, return it.
    if (!/^\/[^\/]/.test(url)) return url;

    var u = (Discourse.BaseUri === undefined ? "/" : Discourse.BaseUri);

    if (u[u.length-1] === '/') u = u.substring(0, u.length-1);
    if (url.indexOf(u) !== -1) return url;
    if (u.length > 0  && url[0] !== "/") url = "/" + url;

    return u + url;
  },

  getURLWithCDN: function(url) {
    url = this.getURL(url);
    // only relative urls
    if (Discourse.CDN && /^\/[^\/]/.test(url)) {
      url = Discourse.CDN + url;
    } else if (Discourse.S3CDN) {
      url = url.replace(Discourse.S3BaseUrl, Discourse.S3CDN);
    }
    return url;
  },

  Resolver: DiscourseResolver,

  _titleChanged: function() {
    var title = this.get('_docTitle') || Discourse.SiteSettings.title;

    // if we change this we can trigger changes on document.title
    // only set if changed.
    if($('title').text() !== title) {
      $('title').text(title);
    }

    var notifyCount = this.get('notifyCount');
    if (notifyCount > 0 && !Discourse.User.currentProp('dynamic_favicon')) {
      title = "(" + notifyCount + ") " + title;
    }

    document.title = title;
  }.observes('_docTitle', 'hasFocus', 'notifyCount'),

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
  }.property(),

  notifyTitle: function(count) {
    this.set('notifyCount', count);
  },

  /**
    Log the current user out of Discourse

    @method logout
  **/
  logout: function() {
    Discourse.User.logout().then(function() {
      // Reloading will refresh unbound properties
      Discourse.KeyValueStore.abandonLocal();

      var redirect = Discourse.SiteSettings.logout_redirect;
      if(redirect.length === 0){
        window.location.pathname = Discourse.getURL('/');
      } else {
        window.location.href = redirect;
      }

    });
  },

  authenticationComplete: function(options) {
    // TODO, how to dispatch this to the controller without the container?
    var loginController = Discourse.__container__.lookup('controller:login');
    return loginController.authenticationComplete(options);
  },

  /**
    Start up the Discourse application by running all the initializers we've defined.

    @method start
  **/
  start: function() {

    $('noscript').remove();

    // Load any ES6 initializers
    Ember.keys(requirejs._eak_seen).forEach(function(key) {
      if (/\/initializers\//.test(key)) {
        var module = require(key, null, null, true);
        if (!module) { throw new Error(key + ' must export an initializer.'); }
        Discourse.initializer(module.default);
      }
    });

  },

  requiresRefresh: function(){
    var desired = Discourse.get("desiredAssetVersion");
    return desired && Discourse.get("currentAssetVersion") !== desired;
  }.property("currentAssetVersion", "desiredAssetVersion"),

  assetVersion: function(prop, val) {
    if(val) {
      if(this.get("currentAssetVersion")){
        this.set("desiredAssetVersion", val);
      } else {
        this.set("currentAssetVersion", val);
      }
    }
    return this.get("currentAssetVersion");
  }.property()

});

// TODO: Remove this, it is in for backwards compatibiltiy with plugins
Discourse.HasCurrentUser = {};
