define("@popperjs/core", ["exports"], function (__exports__) {
  __exports__.default = window.Popper;
  __exports__.createPopper = window.Popper.createPopper;
  __exports__.defaultModifiers = window.Popper.defaultModifiers;
  __exports__.popperGenerator = window.Popper.popperGenerator;
});

define("@uppy/core", ["exports"], function (__exports__) {
  __exports__.default = window.Uppy.Core;
  __exports__.BasePlugin = window.Uppy.Core.BasePlugin;
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

define("@uppy/utils/lib/delay", ["exports"], function (__exports__) {
  __exports__.default = window.Uppy.Utils.delay;
});

define("@uppy/utils/lib/EventTracker", ["exports"], function (__exports__) {
  __exports__.default = window.Uppy.Utils.EventTracker;
});

define("@uppy/utils/lib/AbortController", ["exports"], function (__exports__) {
  __exports__.AbortController =
    window.Uppy.Utils.AbortControllerLib.AbortController;
  __exports__.AbortSignal = window.Uppy.Utils.AbortControllerLib.AbortSignal;
  __exports__.createAbortError =
    window.Uppy.Utils.AbortControllerLib.createAbortError;
});
