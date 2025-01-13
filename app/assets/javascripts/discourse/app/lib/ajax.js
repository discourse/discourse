import { run } from "@ember/runloop";
import $ from "jquery";
import { Promise } from "rsvp";
import getURL from "discourse/lib/get-url";
import userPresent from "discourse/lib/user-presence";
import Session from "discourse/models/session";
import Site from "discourse/models/site";
import User from "discourse/models/user";
import { isTesting } from "discourse-common/config/environment";

let _trackView = false;
let _topicId = null;
let _transientHeader = null;
let _logoffCallback;

export function setTransientHeader(key, value) {
  _transientHeader = { key, value };
}

export function trackNextAjaxAsTopicView(topicId) {
  _topicId = topicId;
}

export function trackNextAjaxAsPageview() {
  _trackView = true;
}

export function resetAjax() {
  _trackView = false;
}

export function setLogoffCallback(cb) {
  _logoffCallback = cb;
}

export function handleLogoff(xhr) {
  if (xhr && xhr.getResponseHeader("Discourse-Logged-Out") && _logoffCallback) {
    _logoffCallback();
  }
}

function handleRedirect(xhr) {
  if (xhr && xhr.getResponseHeader("Discourse-Xhr-Redirect")) {
    window.location = xhr.responseText;
  }
}

export function updateCsrfToken() {
  return ajax("/session/csrf").then((result) => {
    Session.currentProp("csrfToken", result.csrf);
  });
}

/**
  Our own $.ajax method. Makes sure the .then method executes in an Ember runloop
  for performance reasons. Also automatically adjusts the URL to support installs
  in subfolders.
**/

export function ajax() {
  let url, args;
  let ajaxObj;

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

  url = getURL(url);

  let ignoreUnsent = true;
  if (args.ignoreUnsent !== undefined) {
    ignoreUnsent = args.ignoreUnsent;
    delete args.ignoreUnsent;
  }

  function performAjax(resolve, reject) {
    args.headers = args.headers || {};

    if (User.current()) {
      args.headers["Discourse-Logged-In"] = "true";
    }

    if (_transientHeader) {
      args.headers[_transientHeader.key] = _transientHeader.value;
      _transientHeader = null;
    }

    if (_trackView && (!args.type || args.type === "GET")) {
      _trackView = false;
      args.headers["Discourse-Track-View"] = "true";

      if (_topicId) {
        args.headers["Discourse-Track-View-Topic-Id"] = _topicId;
      }
      _topicId = null;
    }

    if (userPresent()) {
      args.headers["Discourse-Present"] = "true";
    }

    args.success = (data, textStatus, xhr) => {
      handleRedirect(xhr);
      handleLogoff(xhr);

      run(() => {
        Site.currentProp(
          "isReadOnly",
          !!(xhr && xhr.getResponseHeader("Discourse-Readonly"))
        );
      });

      if (args.returnXHR) {
        data = { result: data, xhr };
      }

      run(null, resolve, data);
    };

    args.error = (xhr, textStatus, errorThrown) => {
      // 0 represents the `UNSENT` state
      if (ignoreUnsent && xhr.readyState === 0) {
        // Make sure we log pretender errors in test mode
        if (textStatus === "error" && isTesting()) {
          throw errorThrown;
        }
        return;
      }

      handleLogoff(xhr);

      // note: for bad CSRF we don't loop an extra request right away.
      //  this allows us to eliminate the possibility of having a loop.
      if (xhr.status === 403 && xhr.responseText === '["BAD CSRF"]') {
        Session.current().set("csrfToken", null);
      }

      // If it's a parser error, don't reject
      if (xhr.status === 200) {
        return args.success(xhr);
      }

      // Fill in some extra info
      xhr.jqTextStatus = textStatus;
      xhr.requestedUrl = url;

      run(null, reject, {
        jqXHR: xhr,
        textStatus,
        errorThrown,
      });
    };

    if (args.method) {
      args.type = args.method;
      delete args.method;
    }

    // We default to JSON on GET. If we don't, sometimes if the server doesn't return the proper header
    // it will not be parsed as an object.
    if (!args.type) {
      args.type = "GET";
    }
    if (!args.dataType && args.type.toUpperCase() === "GET") {
      args.dataType = "json";
    }

    if (args.dataType === "script") {
      args.headers["Discourse-Script"] = true;
    }

    ajaxObj = $.ajax(url, args);
  }

  let promise;

  // For cached pages we strip out CSRF tokens, need to round trip to server prior to sending the
  //  request (bypass for GET, not needed)
  if (
    args.type &&
    args.type.toUpperCase() !== "GET" &&
    url !== getURL("/clicks/track") &&
    !Session.currentProp("csrfToken")
  ) {
    promise = new Promise((resolve, reject) => {
      ajaxObj = updateCsrfToken().then(() => {
        performAjax(resolve, reject);
      });
    });
  } else {
    promise = new Promise(performAjax);
  }

  promise.abort = () => {
    if (ajaxObj) {
      ajaxObj.abort();
    }
  };

  return promise;
}
