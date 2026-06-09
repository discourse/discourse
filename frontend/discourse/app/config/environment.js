import loadConfigFromMeta from "@embroider/config-meta-loader";
import { isTesting } from "@embroider/macros";

let output;

if (isTesting()) {
  output = {
    modulePrefix: "discourse",
    rootURL: "/",
    locationType: "none",
    APP: {
      autoboot: false,
      rootElement: "#ember-testing",
    },
    EmberENV: {
      _DEFAULT_ASYNC_OBSERVERS: true,
    },
  };
} else {
  output = loadConfigFromMeta("discourse");
}

export default output;
