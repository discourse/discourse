import { importSync } from "@embroider/macros";
import loaderShim from "discourse-common/lib/loader-shim";

// AMD shims for the test bunndle, see the comment in loader-shim.js
loaderShim("pretender", () => importSync("pretender"));
loaderShim("qunit", () => importSync("qunit"));
loaderShim("sinon", () => importSync("sinon"));
