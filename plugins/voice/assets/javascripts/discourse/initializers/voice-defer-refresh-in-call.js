import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  // When a new client version is deployed, core turns the next navigation
  // into a full page load. That would drop the user from their voice room,
  // so hold the refresh until the call is over.
  api.registerValueTransformer(
    "full-page-refresh-on-navigation",
    ({ value }) => {
      const webrtc = api.container.lookup("service:voice-webrtc");
      return webrtc?.hasActiveRoom ? false : value;
    }
  );
});
