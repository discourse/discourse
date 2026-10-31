/* eslint-disable ember/no-jquery */
import { run } from "@ember/runloop";
import $ from "jquery";
import EmbedMode from "discourse/lib/embed-mode";
import { isTesting } from "discourse/lib/environment";
import getURL from "discourse/lib/get-url";
import DiscourseURL from "discourse/lib/url";
import userPresent from "discourse/lib/user-presence";
import Session from "discourse/models/session";
import Site from "discourse/models/site";
import User from "discourse/models/user";

/** jQuery request settings plus the options `ajax` handles itself. */
export interface AjaxOptions extends Omit<
  JQuery.AjaxSettings,
  "url" | "success" | "error"
> {
  url?: string;
  /** Resolve nothing instead of rejecting when the request never left the browser. Defaults to true. */
  ignoreUnsent?: boolean;
  /** Resolve `{ result, xhr }` instead of the response body. */
  returnXHR?: boolean;
}

/** The jqXHR passed to rejection handlers, with the request details `ajax` adds. */
export type AjaxErrorXHR = JQuery.jqXHR & {
  jqTextStatus?: JQuery.Ajax.ErrorTextStatus;
  requestedUrl?: string;
};

/** What an `ajax` promise rejects with. */
export interface AjaxError {
  jqXHR: AjaxErrorXHR;
  textStatus: JQuery.Ajax.ErrorTextStatus;
  errorThrown: string;
}

/**
 * The response promise, plus `abort` to cancel the request.
 *
 * It resolves to `undefined` instead of the body when the response redirects
 * the page or logs the user out.
 */
export type AjaxPromise<T> = Promise<T> & { abort(): void };

/** The `returnXHR` result: the response body and its jqXHR. */
export interface AjaxXHRResult<T> {
  result: T;
  xhr: JQuery.jqXHR;
}

/** The default response type, so JS callers and plugin declarations keep the untyped result. */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
type UntypedResponse = any;

type AjaxRequestArgs = Omit<AjaxOptions, "headers"> & {
  headers?: Record<string, string | number | boolean | null | undefined>;
  success?: (
    data: unknown,
    textStatus: JQuery.Ajax.SuccessTextStatus | JQuery.Ajax.ErrorTextStatus,
    xhr: JQuery.jqXHR
  ) => void;
  error?: (
    xhr: AjaxErrorXHR,
    textStatus: JQuery.Ajax.ErrorTextStatus,
    errorThrown: string
  ) => void;
};

let _trackView = false;
let _topicId: number | null = null;
let _trackingSessionId: string | null = null;
let _trackingUrl: string | null = null;
let _trackingReferrer: string | null = null;
let _transientHeader: { key: string; value: string } | null = null;
let _logoffCallback: (() => void) | undefined;

export function setTransientHeader(key: string, value: string) {
  _transientHeader = { key, value };
}

export function trackNextAjaxAsTopicView(topicId: number) {
  _topicId = topicId;
}

export function trackNextAjaxAsPageview(
  trackingSessionId: string | null,
  trackingUrl: string | null,
  trackingReferrer: string | null
) {
  _trackView = true;
  _trackingSessionId = trackingSessionId;
  _trackingUrl = trackingUrl;
  _trackingReferrer = trackingReferrer;
}

export function resetAjax() {
  _trackView = false;
  _trackingSessionId = null;
  _trackingUrl = null;
  _trackingReferrer = null;
}

export function setLogoffCallback(cb: () => void) {
  _logoffCallback = cb;
}

export function handleLogoff(xhr: JQuery.jqXHR | null | undefined) {
  if (xhr && xhr.getResponseHeader("Discourse-Logged-Out") && _logoffCallback) {
    _logoffCallback();
    return true;
  }
  return false;
}

function handleRedirect(xhr: JQuery.jqXHR | null | undefined) {
  if (xhr && xhr.getResponseHeader("Discourse-Xhr-Redirect")) {
    DiscourseURL.redirectAbsolute(xhr.responseText, { replace: true });
    return true;
  }
  return false;
}

let activeCsrfRequest: Promise<unknown> | null | undefined;

export function updateCsrfToken() {
  if (!activeCsrfRequest) {
    activeCsrfRequest = ajax<{ csrf: string }>("/session/csrf")
      .then((result) => Session.currentProp("csrfToken", result.csrf))
      .finally(() => (activeCsrfRequest = null));
  }

  return activeCsrfRequest;
}

/**
  Our own $.ajax method. Makes sure the .then method executes in an Ember runloop
  for performance reasons. Also automatically adjusts the URL to support installs
  in subfolders.

  `T` is the response body the caller expects; nothing checks it at runtime.
**/
export function ajax<T = UntypedResponse>(
  url: string,
  options: AjaxOptions & { returnXHR: true }
): AjaxPromise<AjaxXHRResult<T>>;
export function ajax<T = UntypedResponse>(
  url: string,
  options?: AjaxOptions
): AjaxPromise<T>;
export function ajax<T = UntypedResponse>(
  options: AjaxOptions & { url: string; returnXHR: true }
): AjaxPromise<AjaxXHRResult<T>>;
export function ajax<T = UntypedResponse>(
  options: AjaxOptions & { url: string }
): AjaxPromise<T>;
export function ajax(
  ...params: [string | (AjaxOptions & { url?: string }), AjaxOptions?]
): AjaxPromise<unknown> {
  // Every supported call shape assigns both below.
  let url!: string, args!: AjaxRequestArgs;
  let ajaxObj: JQuery.jqXHR | undefined;

  if (params.length === 1) {
    if (typeof params[0] === "string") {
      url = params[0];
      args = {};
    } else {
      args = params[0] as AjaxRequestArgs;
      url = args.url!;
      delete args.url;
    }
  } else if (params.length === 2) {
    url = params[0] as string;
    args = params[1] as AjaxRequestArgs;
  }

  url = getURL(url);

  let ignoreUnsent = true;
  if (args.ignoreUnsent !== undefined) {
    ignoreUnsent = args.ignoreUnsent;
    delete args.ignoreUnsent;
  }

  function performAjax(
    resolve: (value?: unknown) => void,
    reject: (reason: AjaxError) => void
  ) {
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

      if (EmbedMode.enabled) {
        args.headers["Discourse-Track-View-Embed"] = "true";
      }

      if (_trackingSessionId) {
        args.headers["Discourse-Track-View-Session-Id"] = _trackingSessionId;
        _trackingSessionId = null;
      }

      if (_trackingUrl) {
        args.headers["Discourse-Track-View-Url"] = _trackingUrl;
        _trackingUrl = null;
      }

      if (_trackingReferrer) {
        args.headers["Discourse-Track-View-Referrer"] = _trackingReferrer;
        _trackingReferrer = null;
      }

      if (_topicId) {
        args.headers["Discourse-Track-View-Topic-Id"] = _topicId;
        _topicId = null;
      }
    }

    if (userPresent()) {
      args.headers["Discourse-Present"] = "true";
    }

    args.success = (data, textStatus, xhr) => {
      if (handleRedirect(xhr) || handleLogoff(xhr)) {
        return resolve();
      }

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

      if (handleRedirect(xhr) || handleLogoff(xhr)) {
        return resolve();
      }

      // note: for bad CSRF we don't loop an extra request right away.
      //  this allows us to eliminate the possibility of having a loop.
      if (xhr.status === 403 && xhr.responseText === '["BAD CSRF"]') {
        Session.current().set("csrfToken", null);
      }

      // If it's a parser error, don't reject
      if (xhr.status === 200) {
        return args.success!(
          xhr.responseJSON ?? xhr.responseText,
          textStatus,
          xhr
        );
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

    ajaxObj = $.ajax(url, args as JQuery.AjaxSettings);
  }

  let promise: AjaxPromise<unknown>;

  // For cached pages we strip out CSRF tokens, need to round trip to server prior to sending the
  //  request (bypass for GET, not needed)
  if (
    args.type &&
    args.type.toUpperCase() !== "GET" &&
    url !== getURL("/clicks/track") &&
    !Session.currentProp("csrfToken")
  ) {
    promise = new Promise((resolve, reject) => {
      updateCsrfToken().then(() => performAjax(resolve, reject), reject);
    }) as AjaxPromise<unknown>;
  } else {
    promise = new Promise(performAjax) as AjaxPromise<unknown>;
  }

  promise.abort = () => {
    if (ajaxObj) {
      ajaxObj.abort();
    }
  };

  return promise;
}
