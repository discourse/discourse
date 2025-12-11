import loadConfigFromMeta from "@embroider/config-meta-loader";
import { isTesting } from "@embroider/macros";

let output;

if (isTesting()) {
  output = {
    modulePrefix: "discourse",
    rootURL: `${import.meta.env.VITE_DISCOURSE_RELATIVE_URL_ROOT}/`,
    locationType: "none",
    APP: {
      autoboot: false,
      rootElement: "#ember-testing",
    },
  };
} else {
  console.log("loadConfigFromMeta", loadConfigFromMeta("discourse"));
  output = loadConfigFromMeta("discourse");
}

export default output;
