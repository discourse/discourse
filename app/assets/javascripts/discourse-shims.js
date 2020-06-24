// Allow us to import Ember
define("ember", ["exports"], function(__exports__) {
  // eslint-disable-next-line no-console
  console.warn(
    [
      "Deprecation notice:",
      "Use specific `@ember/*` imports instead of `ember`",
      "(deprecated since Discourse 2.4.0)",
      "(removal in Discourse 2.5.0)"
    ].join(" ")
  );

  __exports__.default = Ember;
});

define("message-bus-client", ["exports"], function(__exports__) {
  __exports__.default = window.MessageBus;
});
