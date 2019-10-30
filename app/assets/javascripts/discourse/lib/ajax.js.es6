import { run } from "@ember/runloop";
import pageVisible from "discourse/lib/page-visible";
import logout from "discourse/lib/logout";

let _trackView = false;
let _transientHeader = null;
let _showingLogout = false;

export function setTransientHeader(key, value) {
  _transientHeader = { key, value };
}

export function viewTrackingRequired() {
  _trackView = true;
}

export function handleLogoff(xhr) {
  if (xhr.getResponseHeader("Discourse-Logged-Out") && !_showingLogout) {
    _showingLogout = true;
    const messageBus = Discourse.__container__.lookup("message-bus:main");
    messageBus.stop();
    bootbox.dialog(
      I18n.t("logout"),
      { label: I18n.t("refresh"), callback: logout },
      {
        onEscape: () => logout(),
        backdrop: "static"
      }
    );
  }
}

function handleRedirect(data) {
  if (
    data &&
    data.getResponseHeader &&
    data.getResponseHeader("Discourse-Xhr-Redirect")
  ) {
    window.location.replace(data.responseText);
    window.location.reload();
  }
}

export function updateCsrfToken() {
  return ajax("/session/csrf").then(result => {
    Discourse.Session.currentProp("csrfToken", result.csrf);
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

  function performAjax(resolve, reject) {
    args.headers = args.headers || {};

    if (Discourse.__container__.lookup("current-user:main")) {
      args.headers["Discourse-Logged-In"] = "true";
    }

    if (_transientHeader) {
      args.headers[_transientHeader.key] = _transientHeader.value;
      _transientHeader = null;
    }

    if (_trackView && (!args.type || args.type === "GET")) {
      _trackView = false;
      // DON'T CHANGE: rack is prepending "HTTP_" in the header's name
      args.headers["Discourse-Track-View"] = "true";
    }

    if (pageVisible()) {
      args.headers["Discourse-Visible"] = "true";
    }

    args.success = (data, textStatus, xhr) => {
      handleRedirect(data);
      handleLogoff(xhr);

      run(() => {
        Discourse.Site.currentProp(
          "isReadOnly",
          !!xhr.getResponseHeader("Discourse-Readonly")
        );
      });

      if (args.returnXHR) {
        data = { result: data, xhr: xhr };
      }

      run(null, resolve, data);
    };

    args.error = (xhr, textStatus, errorThrown) => {
      // 0 represents the `UNSENT` state
      if (xhr.readyState === 0) return;
      handleLogoff(xhr);

      // note: for bad CSRF we don't loop an extra request right away.
      //  this allows us to eliminate the possibility of having a loop.
      if (xhr.status === 403 && xhr.responseText === '["BAD CSRF"]') {
        Discourse.Session.current().set("csrfToken", null);
      }

      // If it's a parsererror, don't reject
      if (xhr.status === 200) return args.success(xhr);

      // Fill in some extra info
      xhr.jqTextStatus = textStatus;
      xhr.requestedUrl = url;

      run(null, reject, {
        jqXHR: xhr,
        textStatus: textStatus,
        errorThrown: errorThrown
      });
    };

    // We default to JSON on GET. If we don't, sometimes if the server doesn't return the proper header
    // it will not be parsed as an object.
    if (!args.type) args.type = "GET";
    if (!args.dataType && args.type.toUpperCase() === "GET")
      args.dataType = "json";

    if (args.dataType === "script") {
      args.headers["Discourse-Script"] = true;
    }

    if (args.type === "GET" && args.cache !== true) {
      args.cache = true; // Disable JQuery cache busting param, which was created to deal with IE8
    }

    ajaxObj = $.ajax(Discourse.getURL(url), args);
  }

  let promise;

  // For cached pages we strip out CSRF tokens, need to round trip to server prior to sending the
  //  request (bypass for GET, not needed)
  if (
    args.type &&
    args.type.toUpperCase() !== "GET" &&
    url !== Discourse.getURL("/clicks/track") &&
    !Discourse.Session.currentProp("csrfToken")
  ) {
    promise = new Ember.RSVP.Promise((resolve, reject) => {
      ajaxObj = updateCsrfToken().then(() => {
        performAjax(resolve, reject);
      });
    });
  } else {
    promise = new Ember.RSVP.Promise(performAjax);
  }

  promise.abort = () => {
    if (ajaxObj) {
      ajaxObj.abort();
    }
  };

  return promise;
}
