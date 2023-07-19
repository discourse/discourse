import { importSync } from "@embroider/macros";
import loaderShim from "discourse-common/lib/loader-shim";

loaderShim("qunit", () => importSync("qunit"));
loaderShim("sinon", () => importSync("sinon"));
