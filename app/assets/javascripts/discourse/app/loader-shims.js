import { importSync } from "@embroider/macros";
import loaderShim from "discourse-common/lib/loader-shim";

// AMD shims for the app bunndle, see the comment in loader-shim.js
// These effectively become public APIs for plugins, so add/remove them carefully
loaderShim("@discourse/itsatrap", () => importSync("@discourse/itsatrap"));
loaderShim("@ember-compat/tracked-built-ins", () =>
  importSync("@ember-compat/tracked-built-ins")
);
loaderShim("@popperjs/core", () => importSync("@popperjs/core"));
loaderShim("@uppy/aws-s3", () => importSync("@uppy/aws-s3"));
loaderShim("@uppy/aws-s3-multipart", () =>
  importSync("@uppy/aws-s3-multipart")
);
loaderShim("@uppy/core", () => importSync("@uppy/core"));
loaderShim("@uppy/drop-target", () => importSync("@uppy/drop-target"));
loaderShim("@uppy/utils/lib/AbortController", () =>
  importSync("@uppy/utils/lib/AbortController")
);
loaderShim("@uppy/utils/lib/delay", () => importSync("@uppy/utils/lib/delay"));
loaderShim("@uppy/utils/lib/EventTracker", () =>
  importSync("@uppy/utils/lib/EventTracker")
);
loaderShim("@uppy/xhr-upload", () => importSync("@uppy/xhr-upload"));
loaderShim("a11y-dialog", () => importSync("a11y-dialog"));
loaderShim("ember-modifier", () => importSync("ember-modifier"));
loaderShim("handlebars", () => importSync("handlebars"));
loaderShim("js-yaml", () => importSync("js-yaml"));
loaderShim("message-bus-client", () => importSync("message-bus-client"));
loaderShim("tippy.js", () => importSync("tippy.js"));
loaderShim("virtual-dom", () => importSync("virtual-dom"));
loaderShim("xss", () => importSync("xss"));
