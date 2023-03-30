define("I18n", ["exports"], function (exports) {
  return I18n;
});

define("htmlbars-inline-precompile", ["exports"], function (exports) {
  exports.default = function tag(strings) {
    return Ember.Handlebars.compile(strings[0]);
  };
});

define("ember-addons/ember-computed-decorators", [
  "discourse-common/utils/decorators",
  "discourse-common/lib/deprecated",
], function (decorators, deprecated) {
  deprecated.default(
    "ember-addons/ember-computed-decorators is deprecated. Use discourse-common/utils/decorators instead.",
    { since: "2.4", dropFrom: "3.0" }
  );
  return decorators;
});

// Based on https://github.com/emberjs/ember-jquery-legacy
// The addon has out-of-date dependences, but it's super simple so we can reproduce here instead:
define("ember-jquery-legacy", ["exports"], function (exports) {
  exports.normalizeEvent = function (e) {
    if (e instanceof Event) {
      return e;
    }
    // __originalEvent is a private escape hatch of Ember's EventDispatcher to allow accessing `originalEvent` without
    // triggering a deprecation message.
    return e.__originalEvent || e.originalEvent;
  };
});

// ember-cached-decorator-polyfill uses a Babel transformation to apply this polyfill in core.
// Adding that Babel transformation to themes and plugins will be complex, so we use this to
// patch it at runtime. This can be removed once `@glimmer/tracking` is updated to a version
// with native `@cached` support.
const glimmerTracking = require("@glimmer/tracking");
if (glimmerTracking.cached) {
  console.error(
    "@glimmer/tracking natively supports the @cached decorator. The polyfill can be removed."
  );
} else {
  Object.defineProperty(glimmerTracking, "cached", {
    get: () => require("ember-cached-decorator-polyfill").cached,
  });
}

/**
 * Provide AMD/requirejs entrypoint for the custom virtual-dom fork.
 *
 * In order for this to work, the app/app.js must be evaluated before any other
 * modules try to reach for 'virtual-dom'.
 *
 * And note that app/app.js uses the real module name, `@discourse/virtual-dom`.
 */
define("virtual-dom", ["exports"], function (exports) {
  "use strict";

  return {
    default: window.virtualDom,
    __esModule: true,
  };
});
