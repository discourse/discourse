import { apiInitializer } from "discourse/lib/api";
import VoiceBackToVoiceRoomButton from "discourse/plugins/voice/discourse/components/voice-back-to-voice-room-button";

export default apiInitializer((api) => {
  api.renderInOutlet("chat-thread-navbar-actions", VoiceBackToVoiceRoomButton);
});
