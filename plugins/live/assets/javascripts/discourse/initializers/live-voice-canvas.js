import { withPluginApi } from "discourse/lib/plugin-api";
import LiveContextRoom from "discourse/plugins/live/discourse/components/live/context-room";
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
      const liveRooms = owner.lookup("service:live-rooms");
      api.registerValueTransformer("page-shell-context-view", ({ value }) => {
        if (!liveRooms.contextRoom) {
          return value;
        }

        return [
          ...value,
          {
            id: "live",
            label: "live.room.context_view",
            component: LiveContextRoom,
            preferred: liveRooms.prefersContextRoom,
          },
        ];
      });
    });
  },
};
