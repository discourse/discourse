import KeyValueStore from "discourse/lib/key-value-store";

// Per-device dismissal: we record the newest dismissed pin id and reveal the
// bar again once a higher id arrives. Kept on the channel (reactive) and
// mirrored to local storage (survives reloads).
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
