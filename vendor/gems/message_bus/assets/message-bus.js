window.MessageBus = (function() {
  var callbacks, clientId, failCount, interval, isHidden, queue, responseCallbacks, uniqueId;
  uniqueId = function() {
    return 'xxxxxxxxxxxx4xxxyxxxxxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
      var r, v;
      r = Math.random() * 16 | 0;
      v = c === 'x' ? r : r & 0x3 | 0x8;
      return v.toString(16);
    });
  };

  clientId = uniqueId();
  responseCallbacks = {};
  callbacks = [];
  queue = [];
  interval = null;
  failCount = 0;

  isHidden = function() {
    if (document.hidden !== void 0) {
      return document.hidden;
    } else if (document.webkitHidden !== void 0) {
      return document.webkitHidden;
    } else if (document.msHidden !== void 0) {
      return document.msHidden;
    } else if (document.mozHidden !== void 0) {
      return document.mozHidden;
    } else {
      return !document.hasFocus;
    }
  };

  var processMessages = function(messages) {
    failCount = 0;
    $.each(messages,function(idx,message) {
      gotData = true;
      $.each(callbacks,function(idx,callback) {
        if (callback.channel === message.channel) {
          callback.last_id = message.message_id;
          callback.func(message.data);
        }
        if (message.channel === "/__status") {
          if (message.data[callback.channel] !== void 0) {
            callback.last_id = message.data[callback.channel];
          }
        }
      });
    });
  };

  return {

    enableLongPolling: true,
    callbackInterval: 60000,
    maxPollInterval: 3 * 60 * 1000,
    callbacks: callbacks,
    clientId: clientId,
    stop: false,

    start: function(opts) {
      var poll,
        _this = this;
      if (opts === null) {
        opts = {};
      }
      poll = function() {
        var data, gotData;
        if (callbacks.length === 0) {
          setTimeout(poll, 500);
          return;
        }
        data = {};
        $.each(callbacks, function(idx,c) {
          return data[c.channel] = c.last_id === void 0 ? -1 : c.last_id;
        });
        gotData = false;
        return _this.longPoll = $.ajax("/message-bus/" + clientId + "/poll?" + (isHidden() || !_this.enableLongPolling ? "dlp=t" : ""), {
          data: data,
          cache: false,
          dataType: 'json',
          type: 'POST',
          headers: {
            'X-SILENCE-LOGGER': 'true'
          },
          success: function(messages) {
            processMessages(messages);
          },
          error: failCount += 1,
          complete: function() {
            if (gotData) {
              setTimeout(poll, 100);
            } else {
              interval = _this.callbackInterval;
              if (failCount > 2) {
                interval = interval * failCount;
              } else if (isHidden()) {
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

    subscribe: function(channel, func, lastId) {
      callbacks.push({
        channel: channel,
        func: func,
        last_id: lastId
      });
      if (this.longPoll) {
        return this.longPoll.abort();
      }
    },

    unsubscribe: function(channel) {
      var glob;
      if (channel.endsWith("*")) {
        channel = channel.substr(0, channel.length - 1);
        glob = true;
      }
      callbacks = callbacks.filter(function(callback) {
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
})();
