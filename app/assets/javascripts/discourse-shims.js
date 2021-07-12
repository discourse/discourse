// Allow us to import Ember
define("ember", ["exports"], function (__exports__) {
  // eslint-disable-next-line no-console
  console.warn(
    [
      "Deprecation notice:",
      "Use specific `@ember/*` imports instead of `ember`",
      "(deprecated since Discourse 2.4.0)",
      "(removal in Discourse 2.5.0)",
    ].join(" ")
  );

  __exports__.default = Ember;
});

define("message-bus-client", ["exports"], function (__exports__) {
  __exports__.default = window.MessageBus;
});

define("mousetrap-global-bind", ["exports"], function (__exports__) {
  // In the Rails app it's applied from the vendored file
  __exports__.default = {};
});

define("ember-buffered-proxy/proxy", ["exports"], function (__exports__) {
  __exports__.default = window.BufferedProxy;
});

define("bootbox", ["exports"], function (__exports__) {
  __exports__.default = window.bootbox;
});

define("xss", ["exports"], function (__exports__) {
  __exports__.default = window.filterXSS;
});

define("mousetrap", ["exports"], function (__exports__) {
  __exports__.default = window.Mousetrap;
});

define("@popperjs/core", ["exports"], function (__exports__) {
  __exports__.default = window.Popper;
  __exports__.createPopper = window.Popper.createPopper;
  __exports__.defaultModifiers = window.Popper.defaultModifiers;
  __exports__.popperGenerator = window.Popper.popperGenerator;
});

define("@uppy/core", ["exports"], function (__exports__) {
  __exports__.default = window.Uppy.Core;
  __exports__.Plugin = window.Uppy.Plugin;
});

define("@uppy/aws-s3", ["exports"], function (__exports__) {
  __exports__.default = window.Uppy.AwsS3;
});

define("@uppy/aws-s3-multipart", ["exports"], function (__exports__) {
  __exports__.default = window.Uppy.AwsS3Multipart;
});

define("@uppy/xhr-upload", ["exports"], function (__exports__) {
  __exports__.default = window.Uppy.XHRUpload;
});

define("@uppy/drop-target", ["exports"], function (__exports__) {
  __exports__.default = window.Uppy.DropTarget;
});
