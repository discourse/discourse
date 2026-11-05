import { withPluginApi } from "discourse/lib/plugin-api";
import LiveGlobalCallLayer from "discourse/plugins/live/discourse/components/live/global-call-layer";

export default {
  name: "live-voice-canvas",

  initialize(owner) {
    withPluginApi((api) => {
      const currentUser = api.getCurrentUser();
      const siteSettings = owner.lookup("service:site-settings");

      if (!currentUser || !siteSettings.live_enabled) {
        return;
      }

      api.renderInOutlet("below-site-header", LiveGlobalCallLayer);
    });
  },
};
