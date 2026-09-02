// Stage rooms gate speaking on the participant's role; every other room type
// lets anyone speak.
export function participantCanSpeak(room, userId) {
  if (room.room_type !== "stage") {
    return true;
  }

  const participant = (room.active_participants || []).find(
    (p) => Number(p?.id) === Number(userId)
  );
  const role = participant?.role;
  return role === "moderator" || role === "speaker";
}

// Receive-side media policy. Remote client state (muted, role shown in the
// UI) is not proof of what a peer put into its connection: a modified
// listener can attach a microphone track the server would never let it
// unmute. The server-broadcast roster and room capabilities are the
// authority, so a track is only registered and played when the sender's
// server-side role and the room's media policy allow publishing it.
//
// Mic audio arrives with the sender's stream attached; the pre-negotiated
// screen-audio transceiver delivers a bare track (see RemoteStreamRegistry).
export function remoteTrackAllowed(room, userId, track, streams) {
  if (!room || !track) {
    return false;
  }

  const isScreenAudio = track.kind === "audio" && !streams?.length;
  if ((track.kind === "video" || isScreenAudio) && !room.video_allowed) {
    return false;
  }

  return participantCanSpeak(room, userId);
}
