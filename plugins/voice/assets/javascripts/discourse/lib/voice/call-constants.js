// How long a call rings before giving up, mirrored server-side by
// Voice::RoomInviter::RING_SECONDS. Payloads carry their own ring_seconds;
// this is the fallback and the cap for locally started loops.
export const RING_SECONDS = 60;
