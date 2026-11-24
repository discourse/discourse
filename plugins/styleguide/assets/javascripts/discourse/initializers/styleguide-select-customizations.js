import { withPluginApi } from "discourse/lib/plugin-api";
import { markSiteDefault } from "../components/examples/molecules/select/content/held-mark.gjs";

export default {
  name: "styleguide-select-customizations",

  initialize() {
    withPluginApi((api) => {
      api.registerValueTransformer("select-customizations", ({ value }) => {
        markSiteDefault(value);
      });
    });
  },
};
