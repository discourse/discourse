import { withPluginApi } from "discourse/lib/plugin-api";
import VoiceGlobalCallLayer from "discourse/plugins/voice/discourse/components/voice/global-call-layer";

export default {
  name: "voice-voice-canvas",

  initialize(owner) {
    withPluginApi((api) => {
      const currentUser = api.getCurrentUser();
      const siteSettings = owner.lookup("service:site-settings");

      if (!currentUser || !siteSettings.voice_enabled) {
        return;
      }

      api.renderInOutlet("below-site-header", VoiceGlobalCallLayer);
    });
  },
};
