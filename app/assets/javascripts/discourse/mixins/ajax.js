/**
  This mixin provides an 'ajax' method that can be used to perform ajax requests that
  respect Discourse paths and the run loop.

  @class Discourse.Ajax
  @extends Ember.Mixin
  @namespace Discourse
  @module Discourse
**/
Discourse.Ajax = Em.Mixin.create({

  /**
   A generic error handler for .ajax() calls that chains promise failures, for
   use when no better context-sensitive error handler is available (e.g.
   flash() in a modal) and the promise is returned to another function.

   To use, provide Discourse.genericErrorRethrow as the second arg of the then()
   call. Example:

   <code>
   return Discourse.ajax('/path', { options }).then(function(result) {
      // transform result
    }, Discourse.genericErrorRethrow);
   </code>

   Example 2:

   <code>
   return Discourse.ajax('/path', { options }).catch(Discourse.genericErrorRethrow);
   </code>
  **/
  genericErrorRethrow: function(error) {
    Discourse.genericErrorHandler(error);
    throw error;
  },

  /**
    A generic error handler for .ajax() calls, for use when no better context-
    sensitive error handler is available (e.g. flash() in a modal).

    To use, provide Discourse.genericErrorCaught as the second arg of the
    then() call. Example:

    <code>
    Discourse.ajax('/path', { options }).then(function(result) {
      // ...
    }, Discourse.genericErrorCaught);
    </code>
  **/
  genericErrorHandler: function(error) {
    if (error.responseJSON) {
      var $message = $("<p>" + I18n.t('error.autocatch') + "</p>"),
          $list = $("<ul></ul>");
      error.responseJSON.errors.forEach(function(msg) {
        $list.append("<li>" + msg + "</li>");
      });
      bootbox.alert($message.append($list));
    } else {
      bootbox.alert(I18n.t('error.autocatch_nomessage'));
    }
  },

  /**
   * Call Discourse.ajax with standard error behavior.
   */
  ajaxUncaughtError: function() {
    var url, args;

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

    args.errorBehavior = Discourse.AJAXERROR_REJECT;

    Discourse.ajax(url, args);
  },

  /**
   * When an AJAX request fails, go through the standard promise rejection.
   */
  AJAXERROR_REJECT: {reject: true},

  /**
   * When an AJAX request fails, call the generic error handler.
   */
  AJAXERROR_POPUP: {popup: true},

  /**
   * When an AJAX request fails, call the generic error handler and go through
   * the standard promise rejection.
   */
  AJAXERROR_REJECT_AND_POPUP: {reject: true, popup: true},

  /**
   * When an AJAX request fails, do nothing.
   * (This silences the deprecation warning, as opposed to passing an empty object.)
   */
  AJAXERROR_IGNORE: {ignore: true},

  /**
    Our own $.ajax method. Makes sure the .then method executes in an Ember runloop
    for performance reasons. Also automatically adjusts the URL to support installs
    in subfolders.

    @method ajax
  **/
  ajax: function() {
    var url, args;

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
      Ember.Logger.error("DEPRECATION: Discourse.ajax should use promises, received 'success' callback");
    }
    if (args.error) {
      Ember.Logger.error("DEPRECATION: Discourse.ajax should use promises, received 'error' callback");
    }
    if (!args.errorBehavior) {
      // TODO remove this check once plugins get a chance to update
      if (Discourse.Environment.toLowerCase() !== "production") {
        Ember.Logger.error("DEPRECATION: Discourse.ajax calls must specify error behavior (change to Discourse.ajaxUncaughtError to silence)");
      }
      args.errorBehavior = Discourse.AJAXERROR_REJECT;
    }

    // If we have URL_FIXTURES, load from there instead (testing)
    var fixture = Discourse.URL_FIXTURES && Discourse.URL_FIXTURES[url];
    if (fixture) {
      return Ember.RSVP.resolve(fixture);
    }

    var performAjax = function(promise) {
      var oldSuccess = args.success;
      args.success = function(xhr) {
        Ember.run(promise, promise.resolve, xhr);
        if (oldSuccess) oldSuccess(xhr);
      };

      var oldError = args.error;
      args.error = function(xhr) {

        // note: for bad CSRF we don't loop an extra request right away.
        //  this allows us to eliminate the possibility of having a loop.
        if (xhr.status === 403 && xhr.responseText === "['BAD CSRF']") {
          Discourse.Session.current().set('csrfToken', null);
        }

        // If it's a parseerror, don't reject
        if (xhr.status === 200) return args.success(xhr);

        if (args.errorBehavior.reject) {
          Ember.run(promise, promise.reject, xhr);
        }

        if (args.errorBehavior.popup) {
          Discourse.genericErrorHandler(xhr);
        }

        if (oldError) oldError(xhr);
      };

      // We default to JSON for local requests.
      if (!args.type) args.type = 'GET';
      if (!args.dataType && url.indexOf('http') !== 0) args.dataType = 'json';

      $.ajax(Discourse.getURL(url), args);
    };

    // For cached pages we strip out CSRF tokens, need to round trip to server prior to sending the
    //  request (bypass for GET, not needed)
    if (args.type && args.type.toUpperCase() !== 'GET' && !Discourse.Session.currentProp('csrfToken')) {
      return Ember.Deferred.promise(function(promise) {
        $.ajax(Discourse.getURL('/session/csrf'))
            .success(function(result) {
              Discourse.Session.currentProp('csrfToken', result.csrf);
              performAjax(promise);
            });
      });
    } else {
      return Ember.Deferred.promise(performAjax);
    }
  }

});
