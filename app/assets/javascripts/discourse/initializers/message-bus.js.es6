// Initialize the message bus to receive messages.
export default {
  name: "message-bus",
  after: 'inject-objects',

  initialize(container) {
    // We don't use the message bus in testing
    if (Discourse.testing) { return; }

    const messageBus = container.lookup('message-bus:main'),
      user = container.lookup('current-user:main'),
      siteSettings = container.lookup('site-settings:main');

    messageBus.alwaysLongPoll = Discourse.Environment === "development";
    messageBus.start();

    messageBus.callbackInterval = siteSettings.anon_polling_interval;
    messageBus.backgroundCallbackInterval = siteSettings.background_polling_interval;
    messageBus.baseUrl = siteSettings.long_polling_base_url;

    if (messageBus.baseUrl !== '/') {
      // zepto compatible, 1 param only
      messageBus.ajax = function(opts) {
        opts.headers = opts.headers || {};
        opts.headers['X-Shared-Session-Key'] = $('meta[name=shared_session_key]').attr('content');
        return $.ajax(opts);
      };
    } else {
      messageBus.baseUrl = Discourse.getURL('/');
    }

    if (user) {
      messageBus.callbackInterval = siteSettings.polling_interval;
      messageBus.enableLongPolling = true;
    }
  }
};
