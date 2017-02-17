 (function(self) {
'use strict';

var appearsBrowserified = typeof self !== 'undefined' &&
                          typeof process !== 'undefined' &&
                          Object.prototype.toString.call(process) === '[object Object]';

var RouteRecognizer = appearsBrowserified ? require('route-recognizer') : self.RouteRecognizer;
var FakeXMLHttpRequest = appearsBrowserified ? require('fake-xml-http-request') : self.FakeXMLHttpRequest;

/**
 * parseURL - decompose a URL into its parts
 * @param  {String} url a URL
 * @return {Object} parts of the URL, including the following
 *
 * 'https://www.yahoo.com:1234/mypage?test=yes#abc'
 *
 * {
 *   host: 'www.yahoo.com:1234',
 *   protocol: 'https:',
 *   search: '?test=yes',
 *   hash: '#abc',
 *   href: 'https://www.yahoo.com:1234/mypage?test=yes#abc',
 *   pathname: '/mypage',
 *   fullpath: '/mypage?test=yes'
 * }
 */
function parseURL(url) {
  // TODO: something for when document isn't present... #yolo
  var anchor = document.createElement('a');
  anchor.href = url;

  if (!anchor.host) {
    anchor.href = anchor.href; // IE: load the host and protocol
  }

  var pathname = anchor.pathname;
  if (pathname.charAt(0) !== '/') {
    pathname = '/' + pathname; // IE: prepend leading slash
  }

  var host = anchor.host;
  if (anchor.port === '80' || anchor.port === '443') {
    host = anchor.hostname; // IE: remove default port
  }

  return {
    host: host,
    protocol: anchor.protocol,
    search: anchor.search,
    hash: anchor.hash,
    href: anchor.href,
    pathname: pathname,
    fullpath: pathname + (anchor.search || '') + (anchor.hash || '')
  };
}


/**
 * Registry
 *
 * A registry is a map of HTTP verbs to route recognizers.
 */

function Registry(/* host */) {
  // Herein we keep track of RouteRecognizer instances
  // keyed by HTTP method. Feel free to add more as needed.
  this.verbs = {
    GET: new RouteRecognizer(),
    PUT: new RouteRecognizer(),
    POST: new RouteRecognizer(),
    DELETE: new RouteRecognizer(),
    PATCH: new RouteRecognizer(),
    HEAD: new RouteRecognizer(),
    OPTIONS: new RouteRecognizer()
  };
}

/**
 * Hosts
 *
 * a map of hosts to Registries, ultimately allowing
 * a per-host-and-port, per HTTP verb lookup of RouteRecognizers
 */
function Hosts() {
  this._registries = {};
}

/**
 * Hosts#forURL - retrieve a map of HTTP verbs to RouteRecognizers
 *                for a given URL
 *
 * @param  {String} url a URL
 * @return {Registry}   a map of HTTP verbs to RouteRecognizers
 *                      corresponding to the provided URL's
 *                      hostname and port
 */
Hosts.prototype.forURL = function(url) {
  var host = parseURL(url).host;
  var registry = this._registries[host];

  if (registry === undefined) {
    registry = (this._registries[host] = new Registry(host));
  }

  return registry.verbs;
};

function Pretender(/* routeMap1, routeMap2, ...*/) {
  this.hosts = new Hosts();

  this.handlers = [];
  this.handledRequests = [];
  this.passthroughRequests = [];
  this.unhandledRequests = [];
  this.requestReferences = [];

  // reference the native XMLHttpRequest object so
  // it can be restored later
  this._nativeXMLHttpRequest = self.XMLHttpRequest;

  // capture xhr requests, channeling them into
  // the route map.
  self.XMLHttpRequest = interceptor(this, this._nativeXMLHttpRequest);

  // 'start' the server
  this.running = true;

  // trigger the route map DSL.
  for (var i = 0; i < arguments.length; i++) {
    this.map(arguments[i]);
  }
}

function interceptor(pretender, nativeRequest) {
  function FakeRequest() {
    // super()
    FakeXMLHttpRequest.call(this);
  }
  // extend
  var proto = new FakeXMLHttpRequest();
  proto.send = function send() {
    if (!pretender.running) {
      throw new Error('You shut down a Pretender instance while there was a pending request. ' +
            'That request just tried to complete. Check to see if you accidentally shut down ' +
            'a pretender earlier than you intended to');
    }

    FakeXMLHttpRequest.prototype.send.apply(this, arguments);
    if (!pretender.checkPassthrough(this)) {
      pretender.handleRequest(this);
    } else {
      var xhr = createPassthrough(this);
      xhr.send.apply(xhr, arguments);
    }
  };


  function createPassthrough(fakeXHR) {
    // event types to handle on the xhr
    var evts = ['error', 'timeout', 'abort', 'readystatechange'];

    // event types to handle on the xhr.upload
    var uploadEvents = [];

    // properties to copy from the native xhr to fake xhr
    var lifecycleProps = ['readyState', 'responseText', 'responseXML', 'status', 'statusText'];

    var xhr = fakeXHR._passthroughRequest = new pretender._nativeXMLHttpRequest();

    if (fakeXHR.responseType === 'arraybuffer') {
      lifecycleProps = ['readyState', 'response', 'status', 'statusText'];
      xhr.responseType = fakeXHR.responseType;
    }

    // use onload if the browser supports it
    if ('onload' in xhr) {
      evts.push('load');
    }

    // add progress event for async calls
    // avoid using progress events for sync calls, they will hang https://bugs.webkit.org/show_bug.cgi?id=40996.
    if (fakeXHR.async && fakeXHR.responseType !== 'arraybuffer') {
      evts.push('progress');
      uploadEvents.push('progress');
    }

    // update `propertyNames` properties from `fromXHR` to `toXHR`
    function copyLifecycleProperties(propertyNames, fromXHR, toXHR) {
      for (var i = 0; i < propertyNames.length; i++) {
        var prop = propertyNames[i];
        if (fromXHR[prop]) {
          toXHR[prop] = fromXHR[prop];
        }
      }
    }

    // fire fake event on `eventable`
    function dispatchEvent(eventable, eventType, event) {
      eventable.dispatchEvent(event);
      if (eventable['on' + eventType]) {
        eventable['on' + eventType](event);
      }
    }

    // set the on- handler on the native xhr for the given eventType
    function createHandler(eventType) {
      xhr['on' + eventType] = function(event) {
        copyLifecycleProperties(lifecycleProps, xhr, fakeXHR);
        dispatchEvent(fakeXHR, eventType, event);
      };
    }

    // set the on- handler on the native xhr's `upload` property for
    // the given eventType
    function createUploadHandler(eventType) {
      if (xhr.upload) {
        xhr.upload['on' + eventType] = function(event) {
          dispatchEvent(fakeXHR.upload, eventType, event);
        };
      }
    }

    xhr.open(fakeXHR.method, fakeXHR.url, fakeXHR.async, fakeXHR.username, fakeXHR.password);

    var i;
    for (i = 0; i < evts.length; i++) {
      createHandler(evts[i]);
    }
    for (i = 0; i < uploadEvents.length; i++) {
      createUploadHandler(uploadEvents[i]);
    }

    if (fakeXHR.async) {
      xhr.timeout = fakeXHR.timeout;
      xhr.withCredentials = fakeXHR.withCredentials;
    }
    for (var h in fakeXHR.requestHeaders) {
      xhr.setRequestHeader(h, fakeXHR.requestHeaders[h]);
    }
    return xhr;
  }

  proto._passthroughCheck = function(method, args) {
    if (this._passthroughRequest) {
      return this._passthroughRequest[method].apply(this._passthroughRequest, args);
    }
    return FakeXMLHttpRequest.prototype[method].apply(this, args);
  };

  proto.abort = function abort() {
    return this._passthroughCheck('abort', arguments);
  };

  proto.getResponseHeader = function getResponseHeader() {
    return this._passthroughCheck('getResponseHeader', arguments);
  };

  proto.getAllResponseHeaders = function getAllResponseHeaders() {
    return this._passthroughCheck('getAllResponseHeaders', arguments);
  };

  FakeRequest.prototype = proto;

  if (nativeRequest.prototype._passthroughCheck) {
    console.warn('You created a second Pretender instance while there was already one running. ' +
          'Running two Pretender servers at once will lead to unexpected results and will ' +
          'be removed entirely in a future major version.' +
          'Please call .shutdown() on your instances when you no longer need them to respond.');
  }
  return FakeRequest;
}

function verbify(verb) {
  return function(path, handler, async) {
    return this.register(verb, path, handler, async);
  };
}

function scheduleProgressEvent(request, startTime, totalTime) {
  setTimeout(function() {
    if (!request.aborted && !request.status) {
      var ellapsedTime = new Date().getTime() - startTime.getTime();
      request.upload._progress(true, ellapsedTime, totalTime);
      request._progress(true, ellapsedTime, totalTime);
      scheduleProgressEvent(request, startTime, totalTime);
    }
  }, 50);
}

function isArray(array) {
  return Object.prototype.toString.call(array) === '[object Array]';
}

var PASSTHROUGH = {};

Pretender.prototype = {
  get: verbify('GET'),
  post: verbify('POST'),
  put: verbify('PUT'),
  'delete': verbify('DELETE'),
  patch: verbify('PATCH'),
  head: verbify('HEAD'),
  options: verbify('OPTIONS'),
  map: function(maps) {
    maps.call(this);
  },
  register: function register(verb, url, handler, async) {
    if (!handler) {
      throw new Error('The function you tried passing to Pretender to handle ' +
        verb + ' ' + url + ' is undefined or missing.');
    }

    handler.numberOfCalls = 0;
    handler.async = async;
    this.handlers.push(handler);

    var registry = this.hosts.forURL(url)[verb];

    registry.add([{
      path: parseURL(url).fullpath,
      handler: handler
    }]);

    return handler;
  },
  passthrough: PASSTHROUGH,
  checkPassthrough: function checkPassthrough(request) {
    var verb = request.method.toUpperCase();

    var path = parseURL(request.url).fullpath;

    verb = verb.toUpperCase();

    var recognized = this.hosts.forURL(request.url)[verb].recognize(path);
    var match = recognized && recognized[0];
    if (match && match.handler === PASSTHROUGH) {
      this.passthroughRequests.push(request);
      this.passthroughRequest(verb, path, request);
      return true;
    }

    return false;
  },
  handleRequest: function handleRequest(request) {
    var verb = request.method.toUpperCase();
    var path = request.url;

    var handler = this._handlerFor(verb, path, request);

    if (handler) {
      handler.handler.numberOfCalls++;
      var async = handler.handler.async;
      this.handledRequests.push(request);

      var pretender = this;

      var _handleRequest = function(statusHeadersAndBody) {
        if (!isArray(statusHeadersAndBody)) {
          var note = 'Remember to `return [status, headers, body];` in your route handler.';
          throw new Error('Nothing returned by handler for ' + path + '. ' + note);
        }

        var status = statusHeadersAndBody[0],
            headers = pretender.prepareHeaders(statusHeadersAndBody[1]),
            body = pretender.prepareBody(statusHeadersAndBody[2], headers);

        pretender.handleResponse(request, async, function() {
          request.respond(status, headers, body);
          pretender.handledRequest(verb, path, request);
        });
      };

      try {
        var result = handler.handler(request);
        if (result && typeof result.then === 'function') {
          // `result` is a promise, resolve it
          result.then(function(resolvedResult) {
            _handleRequest(resolvedResult);
          });
        } else {
          _handleRequest(result);
        }
      } catch (error) {
        this.erroredRequest(verb, path, request, error);
        this.resolve(request);
      }
    } else {
      this.unhandledRequests.push(request);
      this.unhandledRequest(verb, path, request);
    }
  },
  handleResponse: function handleResponse(request, strategy, callback) {
    var delay = typeof strategy === 'function' ? strategy() : strategy;
    delay = typeof delay === 'boolean' || typeof delay === 'number' ? delay : 0;

    if (delay === false) {
      callback();
    } else {
      var pretender = this;
      pretender.requestReferences.push({
        request: request,
        callback: callback
      });

      if (delay !== true) {
        scheduleProgressEvent(request, new Date(), delay);
        setTimeout(function() {
          pretender.resolve(request);
        }, delay);
      }
    }
  },
  resolve: function resolve(request) {
    for (var i = 0, len = this.requestReferences.length; i < len; i++) {
      var res = this.requestReferences[i];
      if (res.request === request) {
        res.callback();
        this.requestReferences.splice(i, 1);
        break;
      }
    }
  },
  requiresManualResolution: function(verb, path) {
    var handler = this._handlerFor(verb.toUpperCase(), path, {});
    if (!handler) { return false; }

    var async = handler.handler.async;
    return typeof async === 'function' ? async() === true : async === true;
  },
  prepareBody: function(body) { return body; },
  prepareHeaders: function(headers) { return headers; },
  handledRequest: function(/* verb, path, request */) { /* no-op */},
  passthroughRequest: function(/* verb, path, request */) { /* no-op */},
  unhandledRequest: function(verb, path/*, request */) {
    throw new Error('Pretender intercepted ' + verb + ' ' +
      path + ' but no handler was defined for this type of request');
  },
  erroredRequest: function(verb, path, request, error) {
    error.message = 'Pretender intercepted ' + verb + ' ' +
      path + ' but encountered an error: ' + error.message;
    throw error;
  },
  _handlerFor: function(verb, url, request) {
    var registry = this.hosts.forURL(url)[verb];
    var matches = registry.recognize(parseURL(url).fullpath);

    var match = matches ? matches[0] : null;
    if (match) {
      request.params = match.params;
      request.queryParams = matches.queryParams;
    }

    return match;
  },
  shutdown: function shutdown() {
    self.XMLHttpRequest = this._nativeXMLHttpRequest;

    // 'stop' the server
    this.running = false;
  }
};

Pretender.parseURL = parseURL;
Pretender.Hosts = Hosts;
Pretender.Registry = Registry;

if (typeof module === 'object') {
  module.exports = Pretender;
} else if (typeof define !== 'undefined') {
  define('pretender', [], function() {
    return Pretender;
  });
}
self.Pretender = Pretender;
}(self));
