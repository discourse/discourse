import { importSync } from "@embroider/macros";
import loaderShim from "discourse/lib/loader-shim";

// AMD shims for the app bundle, see the comment in loader-shim.js
// These effectively become public APIs for plugins, so add/remove them carefully
loaderShim("@discourse/itsatrap", () => importSync("@discourse/itsatrap"));
loaderShim("@ember-compat/tracked-built-ins", () =>
  importSync("@ember-compat/tracked-built-ins")
);
loaderShim("@ember/-internals/metal", () =>
  importSync("@ember/-internals/metal")
);
loaderShim("@ember/object/internals", () =>
  importSync("@ember/object/internals")
);
loaderShim("@ember/application", () => importSync("@ember/application"));
loaderShim("@ember/application/instance", () =>
  importSync("@ember/application/instance")
);
loaderShim("@ember/array", () => importSync("@ember/array"));
loaderShim("@ember/array/proxy", () => importSync("@ember/array/proxy"));
loaderShim("@ember/component", () => importSync("@ember/component"));
loaderShim("@ember/component/helper", () =>
  importSync("@ember/component/helper")
);
loaderShim("@ember/component/template-only", () =>
  importSync("@ember/component/template-only")
);
loaderShim("@ember/component/template-only", () =>
  importSync("@ember/component/template-only")
);
loaderShim("@ember/controller", () => importSync("@ember/controller"));
loaderShim("@ember/debug", () => importSync("@ember/debug"));
loaderShim("@ember/destroyable", () => importSync("@ember/destroyable"));
loaderShim("@ember/helper", () => importSync("@ember/helper"));
loaderShim("@ember/modifier", () => importSync("@ember/modifier"));
loaderShim("@ember/object", () => importSync("@ember/object"));
loaderShim("@ember/object/compat", () => importSync("@ember/object/compat"));
loaderShim("@ember/object/computed", () =>
  importSync("@ember/object/computed")
);
loaderShim("@ember/object/evented", () => importSync("@ember/object/evented"));
loaderShim("@ember/object/mixin", () => importSync("@ember/object/mixin"));
loaderShim("@ember/object/observers", () =>
  importSync("@ember/object/observers")
);
loaderShim("@ember/owner", () => importSync("@ember/owner"));
loaderShim("@ember/reactive/collections", () =>
  importSync("@ember/reactive/collections")
);
loaderShim("@ember/render-modifiers/modifiers/did-insert", () =>
  importSync("@ember/render-modifiers/modifiers/did-insert")
);
loaderShim("@ember/render-modifiers/modifiers/did-update", () =>
  importSync("@ember/render-modifiers/modifiers/did-update")
);
loaderShim("@ember/render-modifiers/modifiers/will-destroy", () =>
  importSync("@ember/render-modifiers/modifiers/will-destroy")
);
loaderShim("@ember/routing", () => importSync("@ember/routing"));
loaderShim("@ember/routing/route", () => importSync("@ember/routing/route"));
loaderShim("@ember/runloop", () => importSync("@ember/runloop"));
loaderShim("@ember/service", () => importSync("@ember/service"));
loaderShim("@ember/string", () => importSync("@ember/string"));
loaderShim("@ember/template-factory", () =>
  importSync("@ember/template-factory")
);
loaderShim("@ember/template", () => importSync("@ember/template"));
loaderShim("@ember/test-waiters", () => importSync("@ember/test-waiters"));
loaderShim("@ember/utils", () => importSync("@ember/utils"));
loaderShim("@floating-ui/dom", () => importSync("@floating-ui/dom"));
loaderShim("@glimmer/component", () => importSync("@glimmer/component"));
loaderShim("@glimmer/tracking", () => importSync("@glimmer/tracking"));
loaderShim("@uppy/aws-s3", () => importSync("@uppy/aws-s3"));
loaderShim("@uppy/core", () => importSync("@uppy/core"));
loaderShim("@uppy/drop-target", () => importSync("@uppy/drop-target"));
loaderShim("@uppy/utils", () => importSync("@uppy/utils"));
loaderShim("@uppy/xhr-upload", () => importSync("@uppy/xhr-upload"));
loaderShim("a11y-dialog", () => importSync("a11y-dialog"));
loaderShim("discourse-i18n", () => importSync("discourse-i18n"));
loaderShim("ember-async-data", () => importSync("ember-async-data"));
loaderShim("ember-curry-component", () => importSync("ember-curry-component"));
loaderShim("ember-modifier", () => importSync("ember-modifier"));
loaderShim("ember-route-template", () => importSync("ember-route-template"));
loaderShim("ember", () => importSync("ember"));
loaderShim("jquery", () => importSync("jquery"));
loaderShim("js-yaml", () => importSync("js-yaml"));
loaderShim("moment", () => importSync("moment"));
loaderShim("rsvp", () => importSync("rsvp"));
loaderShim("discourse/truth-helpers", () =>
  importSync("discourse/truth-helpers")
);
loaderShim("truth-helpers", () => importSync("discourse/truth-helpers"));
loaderShim("truth-helpers/helpers/and", () =>
  importSync("discourse/truth-helpers/helpers/and")
);
loaderShim("truth-helpers/helpers/eq", () =>
  importSync("discourse/truth-helpers/helpers/eq")
);
loaderShim("truth-helpers/helpers/gt", () =>
  importSync("discourse/truth-helpers/helpers/gt")
);
loaderShim("truth-helpers/helpers/gte", () =>
  importSync("discourse/truth-helpers/helpers/gte")
);
loaderShim("truth-helpers/helpers/includes", () =>
  importSync("discourse/truth-helpers/helpers/includes")
);
loaderShim("truth-helpers/helpers/lt", () =>
  importSync("discourse/truth-helpers/helpers/lt")
);
loaderShim("truth-helpers/helpers/lte", () =>
  importSync("discourse/truth-helpers/helpers/lte")
);
loaderShim("truth-helpers/helpers/not-eq", () =>
  importSync("discourse/truth-helpers/helpers/not-eq")
);
loaderShim("truth-helpers/helpers/not", () =>
  importSync("discourse/truth-helpers/helpers/not")
);
loaderShim("truth-helpers/helpers/or", () =>
  importSync("discourse/truth-helpers/helpers/or")
);
loaderShim("xss", () => importSync("xss"));
loaderShim("ember-this-fallback/deprecations-helper", () =>
  importSync("./lib/ember-this-fallback-deprecation-helper")
);
loaderShim("pretty-text/allow-lister", () =>
  importSync("pretty-text/allow-lister")
);
loaderShim("pretty-text/censored-words", () =>
  importSync("pretty-text/censored-words")
);
loaderShim("pretty-text/emoji", () => importSync("pretty-text/emoji"));
loaderShim("pretty-text/emoji/data", () =>
  importSync("pretty-text/emoji/data")
);
loaderShim("pretty-text/emoji/version", () =>
  importSync("pretty-text/emoji/version")
);
loaderShim("pretty-text/guid", () => importSync("pretty-text/guid"));
loaderShim("pretty-text/inline-oneboxer", () =>
  importSync("pretty-text/inline-oneboxer")
);
loaderShim("pretty-text/mentions", () => importSync("pretty-text/mentions"));
loaderShim("pretty-text/oneboxer", () => importSync("pretty-text/oneboxer"));
loaderShim("pretty-text/oneboxer-cache", () =>
  importSync("pretty-text/oneboxer-cache")
);
loaderShim("pretty-text/pretty-text", () =>
  importSync("pretty-text/pretty-text")
);
loaderShim("pretty-text/sanitizer", () => importSync("pretty-text/sanitizer"));
loaderShim("pretty-text/text-replace", () =>
  importSync("pretty-text/text-replace")
);
loaderShim("pretty-text/upload-short-url", () =>
  importSync("pretty-text/upload-short-url")
);
loaderShim("@ember-decorators/component", () =>
  importSync("@ember-decorators/component")
);
loaderShim("@ember-decorators/object", () =>
  importSync("@ember-decorators/object")
);
loaderShim("discourse/lib/transformer/registry", () =>
  importSync("discourse/lib/registry/transformers")
);
loaderShim("discourse/modifiers/did-insert", () =>
  importSync("@ember/render-modifiers/modifiers/did-insert")
);
loaderShim("discourse/modifiers/did-update", () =>
  importSync("@ember/render-modifiers/modifiers/did-update")
);
loaderShim("discourse/modifiers/will-destroy", () =>
  importSync("@ember/render-modifiers/modifiers/will-destroy")
);
loaderShim("ember-this-fallback/deprecations-helper", () =>
  importSync("./lib/ember-this-fallback/deprecations-helper")
);
loaderShim("ember-this-fallback/is-component", () =>
  importSync("./lib/ember-this-fallback/is-component")
);
loaderShim("ember-this-fallback/this-fallback-helper", () =>
  importSync("./lib/ember-this-fallback/this-fallback-helper")
);
loaderShim("ember-this-fallback/try-lookup-helper", () =>
  importSync("./lib/ember-this-fallback/try-lookup-helper")
);
loaderShim("ember-buffered-proxy/helpers", () =>
  importSync("ember-buffered-proxy/helpers")
);
loaderShim("ember-buffered-proxy/mixin", () =>
  importSync("ember-buffered-proxy/mixin")
);
loaderShim("ember-buffered-proxy/proxy", () =>
  importSync("ember-buffered-proxy/proxy")
);
