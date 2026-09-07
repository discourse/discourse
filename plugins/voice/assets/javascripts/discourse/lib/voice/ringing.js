import { RING_SECONDS } from "./call-constants";

// People an ephemeral call room is still reaching out to: rung, not yet
// present, and within the ring window. `nowMs` comes from the caller's
// clock tick so expiry re-evaluates over time (getters alone never would).
export function activeRingingEntries(room, nowMs) {
  if (!room?.ephemeral) {
    return [];
  }

  const presentIds = new Set(
    (room.active_participants || []).map((participant) =>
      Number(participant?.id)
    )
  );
  const cutoff = nowMs - RING_SECONDS * 1000;

  return (room.ringing || []).filter(
    (entry) =>
      entry.user &&
      !presentIds.has(Number(entry.user.id)) &&
      entry.notified_at * 1000 > cutoff
  );
}
