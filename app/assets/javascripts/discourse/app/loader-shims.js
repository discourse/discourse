import { importSync } from "@embroider/macros";
import loaderShim from "discourse/lib/loader-shim";

// AMD shims for the app bundle, see the comment in loader-shim.js
// These effectively become public APIs for plugins, so add/remove them carefully
loaderShim("@glimmer/component", () => importSync("@glimmer/component"));
loaderShim("@ember/helper", () => importSync("@ember/helper"));
loaderShim("@ember/modifier", () => importSync("@ember/modifier"));
loaderShim("@ember/object", () => importSync("@ember/object"));
loaderShim("@ember/template", () => importSync("@ember/template"));
loaderShim("@ember/template-factory", () =>
  importSync("@ember/template-factory")
);
loaderShim("@ember/render-modifiers/modifiers/did-insert", () =>
  importSync("@ember/render-modifiers/modifiers/did-insert")
);
loaderShim("@ember/render-modifiers/modifiers/did-update", () =>
  importSync("@ember/render-modifiers/modifiers/did-update")
);
loaderShim("@ember/runloop", () => importSync("@ember/runloop"));
loaderShim("@ember/service", () => importSync("@ember/service"));
loaderShim("@ember/component", () => importSync("@ember/component"));
loaderShim("@glimmer/tracking", () => importSync("@glimmer/tracking"));
loaderShim("discourse/components/conditional-loading-spinner", () =>
  importSync("discourse/components/conditional-loading-spinner")
);
loaderShim("discourse/components/d-modal", () =>
  importSync("discourse/components/d-modal")
);
loaderShim("discourse/components/d-button", () =>
  importSync("discourse/components/d-button")
);
loaderShim("discourse/helpers/loading-spinner", () =>
  importSync("discourse/helpers/loading-spinner")
);
loaderShim("discourse/lib/debounce", () =>
  importSync("discourse/lib/debounce")
);
loaderShim("discourse/lib/plugin-api", () =>
  importSync("discourse/lib/plugin-api")
);
loaderShim("@discourse/itsatrap", () => importSync("@discourse/itsatrap"));
loaderShim("@ember-compat/tracked-built-ins", () =>
  importSync("@ember-compat/tracked-built-ins")
);
loaderShim("@popperjs/core", () => importSync("@popperjs/core"));
loaderShim("@floating-ui/dom", () => importSync("@floating-ui/dom"));
loaderShim("@uppy/aws-s3", () => importSync("@uppy/aws-s3"));
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
loaderShim("discourse-i18n", () => importSync("discourse-i18n"));
loaderShim("ember-modifier", () => importSync("ember-modifier"));
loaderShim("ember-route-template", () => importSync("ember-route-template"));
loaderShim("jquery", () => importSync("jquery"));
loaderShim("js-yaml", () => importSync("js-yaml"));
loaderShim("message-bus-client", () => importSync("message-bus-client"));
loaderShim("virtual-dom", () => importSync("virtual-dom"));
loaderShim("xss", () => importSync("xss"));
loaderShim("truth-helpers", () => importSync("truth-helpers"));
loaderShim("truth-helpers/helpers/and", () =>
  importSync("truth-helpers/helpers/and")
);
loaderShim("truth-helpers/helpers/eq", () =>
  importSync("truth-helpers/helpers/eq")
);
loaderShim("truth-helpers/helpers/gt", () =>
  importSync("truth-helpers/helpers/gt")
);
loaderShim("truth-helpers/helpers/gte", () =>
  importSync("truth-helpers/helpers/gte")
);
loaderShim("truth-helpers/helpers/includes", () =>
  importSync("truth-helpers/helpers/includes")
);
loaderShim("truth-helpers/helpers/lt", () =>
  importSync("truth-helpers/helpers/lt")
);
loaderShim("truth-helpers/helpers/lte", () =>
  importSync("truth-helpers/helpers/lte")
);
loaderShim("truth-helpers/helpers/not-eq", () =>
  importSync("truth-helpers/helpers/not-eq")
);
loaderShim("truth-helpers/helpers/not", () =>
  importSync("truth-helpers/helpers/not")
);
loaderShim("truth-helpers/helpers/or", () =>
  importSync("truth-helpers/helpers/or")
);
loaderShim("@messageformat/runtime/messages", () =>
  importSync("@messageformat/runtime/messages")
);
loaderShim("@messageformat/runtime", () =>
  importSync("@messageformat/runtime")
);
loaderShim("@messageformat/runtime/lib/cardinals", () =>
  importSync("@messageformat/runtime/lib/cardinals")
);
loaderShim("@ember/string", () => importSync("@ember/string"));
loaderShim("moment", () => importSync("moment"));
