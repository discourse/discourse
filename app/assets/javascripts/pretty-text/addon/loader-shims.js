import { importSync } from "@embroider/macros";
import loaderShim from "discourse-common/lib/loader-shim";

// AMD shims for the addon, see the comment in loader-shim.js
// These effectively become public APIs for plugins, so add/remove them carefully
// Note that this is included into the main app bundle for core
loaderShim("xss", () => importSync("xss"));
