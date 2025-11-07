import { withPluginApi } from "discourse/lib/plugin-api";
import AdType from "../models/ad-type";

function extendSite(api) {
  // Transform ad_types from backend format to AdType objects
  api.modifyClass("model:site", {
    pluginId: "discourse-adplugin",

    init() {
      this._super(...arguments);

      if (this.ad_types) {
        this.adTypes = Object.entries(this.ad_types).map(
          ([key, id]) => new AdType(id, key)
        );
        delete this.ad_types;
      }
    },
  });
}

export default {
  name: "extend-site-with-ad-types",

  initialize() {
    withPluginApi(extendSite);
  },
};
