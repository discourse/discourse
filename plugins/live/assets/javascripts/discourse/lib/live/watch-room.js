import { modifier } from "ember-modifier";

// Tie ownership to the rendered surface, including argument changes and hiding,
// rather than the lifetime of the always-mounted call widget component.
export default modifier(function watchRoom(
  element,
  [liveWebrtc, roomId],
  { disabled = false, keepVideo }
) {
  if (roomId && !disabled) {
    return liveWebrtc.acquireVideoWatch(roomId, { keepVideo });
  }
});
