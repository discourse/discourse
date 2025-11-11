import { importSync } from "@embroider/macros";
import otherLoader from "discourse/lib/loader-shim";

const discourseModules = import.meta.glob("./**/*.{gjs,js}");
// console.log(discourseModules);

window.moduleBroker = {
  lookup: async function (moduleName) {
    // discourse/components/d-button
    // {
    //   '../components/d-button.gjs': load() {}
    // }

    const name = moduleName.replace(/^discourse\//, "./");
    try {
      // TODO: clean up
      return await (
        discourseModules[`${name}.gjs`] ||
        discourseModules[`${name}.js`] ||
        discourseModules[name]
      )();
    } catch (error) {
      debugger;
      // console.error(error);
      throw error;
    }

    // return require(moduleName);
  },
};

// export const map = {};

function loaderShim(pkg, callback) {
  // if (!__require__.has(pkg)) {
  //   __define__(pkg, callback);
  // }
  discourseModules[pkg] = callback;
}

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
loaderShim("@ember/component/template-only", () =>
  importSync("@ember/component/template-only")
);
loaderShim("@glimmer/tracking", () => importSync("@glimmer/tracking"));
loaderShim("@discourse/itsatrap", () => importSync("@discourse/itsatrap"));
loaderShim("@ember-compat/tracked-built-ins", () =>
  importSync("@ember-compat/tracked-built-ins")
);
loaderShim("@ember/-internals/metal", () =>
  importSync("@ember/-internals/metal")
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
loaderShim("@ember/render-modifiers/modifiers/did-insert", () =>
  importSync("@ember/render-modifiers/modifiers/did-insert")
);
loaderShim("@ember/render-modifiers/modifiers/did-update", () =>
  importSync("@ember/render-modifiers/modifiers/did-update")
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
loaderShim("@ember/utils", () => importSync("@ember/utils"));
loaderShim("@floating-ui/dom", () => importSync("@floating-ui/dom"));
loaderShim("@glimmer/component", () => importSync("@glimmer/component"));
loaderShim("@glimmer/tracking", () => importSync("@glimmer/tracking"));
loaderShim("@messageformat/runtime", () =>
  importSync("@messageformat/runtime")
);
loaderShim("@messageformat/runtime/lib/cardinals", () =>
  importSync("@messageformat/runtime/lib/cardinals")
);
loaderShim("@messageformat/runtime/messages", () =>
  importSync("@messageformat/runtime/messages")
);
loaderShim("@popperjs/core", () => importSync("@popperjs/core"));
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
loaderShim("ember-curry-component", () => importSync("ember-curry-component"));
loaderShim("ember-modifier", () => importSync("ember-modifier"));
loaderShim("ember-route-template", () => importSync("ember-route-template"));
loaderShim("ember", () => importSync("ember"));
loaderShim("jquery", () => importSync("jquery"));
loaderShim("js-yaml", () => importSync("js-yaml"));
loaderShim("virtual-dom", () => importSync("virtual-dom"));
loaderShim("xss", () => importSync("xss"));
// loaderShim("message-bus-client", () => importSync("message-bus-client"));
loaderShim("moment", () => importSync("moment"));
loaderShim("rsvp", () => importSync("rsvp"));
loaderShim("virtual-dom", () => importSync("virtual-dom"));
loaderShim("xss", () => importSync("xss"));
otherLoader("@messageformat/runtime/messages", () =>
  importSync("@messageformat/runtime/messages")
);
otherLoader("@messageformat/runtime", () =>
  importSync("@messageformat/runtime")
);
otherLoader("@messageformat/runtime/lib/cardinals", () =>
  importSync("@messageformat/runtime/lib/cardinals")
);
loaderShim("@ember/string", () => importSync("@ember/string"));
loaderShim("moment", () => importSync("moment"));
loaderShim("ember-curry-component", () => importSync("ember-curry-component"));
loaderShim("@ember-decorators/component", () =>
  importSync("@ember-decorators/component")
);
