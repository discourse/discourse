import KeyValueStore from "discourse/lib/key-value-store";

// A user can hide the pinned bar for a channel; the dismissal is recorded as
// "everything up to this pin id" so the bar stays hidden until a newer pin is
// added. Pin ids auto-increment, so "a newer pin exists" === "the newest pin
// id increased" — order-independent.
//
// The live dismissal is a tracked prop on the channel (reactive within the
// session); this store is the per-device fallback that restores it across
// reloads without writing during render.
export const STORE_NAMESPACE = "discourse_chat_pinned_bar_";

const store = new KeyValueStore(STORE_NAMESPACE);

export function newestPinId(pins) {
  return pins.length ? Math.max(...pins.map((pin) => pin.id)) : null;
}

export function dismissPinsUpTo(channel, pinId) {
  channel.pinsDismissedAboveId = pinId;
  store.setObject({ key: String(channel.id), value: pinId });
}

export function pinsDismissedAboveId(channel) {
  return channel.pinsDismissedAboveId ?? store.getObject(String(channel.id));
}

export function hasPinsDismissal(channel) {
  return pinsDismissedAboveId(channel) != null;
}

export function resetPinsDismissal(channel) {
  channel.pinsDismissedAboveId = null;
  store.remove(String(channel.id));
}
