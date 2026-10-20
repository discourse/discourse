import { apiInitializer } from "discourse/lib/api";
import LiveBackToLiveRoomButton from "discourse/plugins/live/discourse/components/live-back-to-live-room-button";

export default apiInitializer((api) => {
  api.renderInOutlet("chat-thread-navbar-actions", LiveBackToLiveRoomButton);
});
