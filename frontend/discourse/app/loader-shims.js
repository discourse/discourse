import { importSync } from "@embroider/macros";
import loaderShim from "discourse/lib/loader-shim";

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
// Needed in production: plugins register their dynamic imports so tests wait for them.
loaderShim("@ember/test-waiters", () => importSync("@ember/test-waiters"));
loaderShim("@ember/utils", () => importSync("@ember/utils"));
loaderShim("@glimmer/component", () => importSync("@glimmer/component"));
loaderShim("@glimmer/tracking", () => importSync("@glimmer/tracking"));
