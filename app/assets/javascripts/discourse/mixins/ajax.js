/**
  This mixin provides an 'ajax' method that can be used to perform ajax requests that
  respect Discourse paths and the run loop.
**/
var _trackView = false;

Discourse.Ajax = Em.Mixin.create({

  viewTrackingRequired: function() {
    _trackView = true;
  },

  /**
    Our own $.ajax method. Makes sure the .then method executes in an Ember runloop
    for performance reasons. Also automatically adjusts the URL to support installs
    in subfolders.

    @method ajax
  **/
  ajax: function() {
    var url, args;
    var ajax;

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
      throw "Discourse.ajax should use promises, received 'success' callback";
    }
    if (args.error) {
      throw "DEPRECATION: Discourse.ajax should use promises, received 'error' callback";
    }

    var performAjax = function(resolve, reject) {

      args.headers = args.headers || {};

      if (_trackView && (!args.type || args.type === "GET")) {
        _trackView = false;
        // DON'T CHANGE: rack is prepending "HTTP_" in the header's name
        args.headers['Discourse-Track-View'] = "true";
      }

      args.success = function(data, textStatus, xhr) {
        if (xhr.getResponseHeader('Discourse-Readonly')) {
          Ember.run(function() {
            Discourse.Site.currentProp('isReadOnly', true);
          });
        }

        Ember.run(null, resolve, data);
      };

      args.error = function(xhr, textStatus, errorThrown) {
        // note: for bad CSRF we don't loop an extra request right away.
        //  this allows us to eliminate the possibility of having a loop.
        if (xhr.status === 403 && xhr.responseText === "['BAD CSRF']") {
          Discourse.Session.current().set('csrfToken', null);
        }

        // If it's a parsererror, don't reject
        if (xhr.status === 200) return args.success(xhr);

        // Fill in some extra info
        xhr.jqTextStatus = textStatus;
        xhr.requestedUrl = url;

        Ember.run(null, reject, {
          jqXHR: xhr,
          textStatus: textStatus,
          errorThrown: errorThrown
        });
      };

      // We default to JSON on GET. If we don't, sometimes if the server doesn't return the proper header
      // it will not be parsed as an object.
      if (!args.type) args.type = 'GET';
      if (!args.dataType && args.type.toUpperCase() === 'GET') args.dataType = 'json';

      if (args.dataType === "script") {
        args.headers['Discourse-Script'] = true;
      }

      if (args.type === 'GET' && args.cache !== true) {
        args.cache = false;
      }

      ajax = $.ajax(Discourse.getURL(url), args);
    };

    var promise;

    // For cached pages we strip out CSRF tokens, need to round trip to server prior to sending the
    //  request (bypass for GET, not needed)
    if(args.type && args.type.toUpperCase() !== 'GET' && !Discourse.Session.currentProp('csrfToken')){
      promise = new Ember.RSVP.Promise(function(resolve, reject){
        ajax = $.ajax(Discourse.getURL('/session/csrf'), {cache: false})
           .success(function(result){
              Discourse.Session.currentProp('csrfToken', result.csrf);
              performAjax(resolve, reject);
           });
      });
    } else {
      promise = new Ember.RSVP.Promise(performAjax);
    }

    promise.abort = function(){
      if (ajax) {
        ajax.abort();
      }
    };

    return promise;
  }

});
