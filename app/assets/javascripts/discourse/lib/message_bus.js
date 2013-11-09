/*jshint bitwise: false*/

/**
  Message Bus functionality.

  @class MessageBus
  @namespace Discourse
  @module Discourse
**/
Discourse.MessageBus = (function() {
  // http://stackoverflow.com/questions/105034/how-to-create-a-guid-uuid-in-javascript
  var callbacks, clientId, failCount, interval, shouldLongPoll, queue, responseCallbacks, uniqueId;
  var me;

  uniqueId = function() {
    return 'xxxxxxxxxxxx4xxxyxxxxxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
      var r, v;
      r = Math.random() * 16 | 0;
      v = c === 'x' ? r : (r & 0x3 | 0x8);
      return v.toString(16);
    });
  };

  clientId = uniqueId();
  responseCallbacks = {};
  callbacks = [];
  queue = [];
  interval = null;
  failCount = 0;

  var isHidden = function() {
    if (document.hidden !== void 0) {
      return document.hidden;
    } else if (document.webkitHidden !== void 0) {
      return document.webkitHidden;
    } else if (document.msHidden !== void 0) {
      return document.msHidden;
    } else if (document.mozHidden !== void 0) {
      return document.mozHidden;
    } else {
      // fallback to problamatic window.focus
      return !Discourse.get('hasFocus');
    }
  };

  shouldLongPoll = function() {
    return me.alwaysLongPoll || !isHidden();
  };

  me = {
    enableLongPolling: true,
    callbackInterval: 60000,
    maxPollInterval: 3 * 60 * 1000,
    callbacks: callbacks,
    clientId: clientId,
    alwaysLongPoll: false,
    stop: false,

    // Start polling
    start: function(opts) {
      var poll,
        _this = this;
      if (!opts) opts = {};

      poll = function() {
        var data, gotData;
        if (callbacks.length === 0) {
          setTimeout(poll, 500);
          return;
        }
        data = {};
        _.each(callbacks, function(callback) {
          data[callback.channel] = callback.last_id;
        });
        gotData = false;
        _this.longPoll = $.ajax(Discourse.getURL("/message-bus/") + clientId + "/poll?" + (!shouldLongPoll() || !_this.enableLongPolling ? "dlp=t" : ""), {
          data: data,
          cache: false,
          dataType: 'json',
          type: 'POST',
          headers: {
            'X-SILENCE-LOGGER': 'true'
          },
          success: function(messages) {
            failCount = 0;
            _.each(messages,function(message) {
              gotData = true;
              _.each(callbacks, function(callback) {
                if (callback.channel === message.channel) {
                  callback.last_id = message.message_id;
                  callback.func(message.data);
                }
                if (message.channel === "/__status") {
                  if (message.data[callback.channel] !== undefined) {
                    callback.last_id = message.data[callback.channel];
                  }
                }
              });
            });
          },
          error: failCount += 1,
          complete: function() {
            if (gotData) {
              setTimeout(poll, 100);
            } else {
              interval = _this.callbackInterval;
              if (failCount > 2) {
                interval = interval * failCount;
              } else if (!shouldLongPoll()) {
                // slowning down stuff a lot when hidden
                // we will need to add a lot of fine tuning here
                interval = interval * 4;
              }
              if (interval > _this.maxPollInterval) {
                interval = _this.maxPollInterval;
              }
              setTimeout(poll, interval);
            }
            _this.longPoll = null;
          }
        });
      };
      poll();
    },

    // Subscribe to a channel
    subscribe: function(channel, func, lastId) {
      if (typeof(lastId) !== "number" || lastId < -1){
        lastId = -1;
      }
      callbacks.push({
        channel: channel,
        func: func,
        last_id: lastId
      });
      if (this.longPoll) {
        return this.longPoll.abort();
      }
    },

    // Unsubscribe from a channel
    unsubscribe: function(channel) {
      // TODO proper globbing
      var glob;
      if (channel.indexOf("*", channel.length - 1) !== -1) {
        channel = channel.substr(0, channel.length - 1);
        glob = true;
      }
      callbacks = $.grep(callbacks,function(callback) {
        if (glob) {
          return callback.channel.substr(0, channel.length) !== channel;
        } else {
          return callback.channel !== channel;
        }
      });
      if (this.longPoll) {
        return this.longPoll.abort();
      }
    }
  };

  return me;
})();
