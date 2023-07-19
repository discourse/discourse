import { importSync } from "@embroider/macros";
import loaderShim from "discourse-common/lib/loader-shim";

loaderShim("xss", () => importSync("xss"));

// We don't actually need to run anything
export default {
  initialize() {},
};
