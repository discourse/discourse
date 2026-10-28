export function participantCanSpeak(room, userId) {
  if (room.room_type !== "stage" && Number(userId) > 0) {
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
// On mesh rooms nothing else stands between a sender and its peers, so a
// camera, screen, or screen-audio track additionally requires the sender's
// own server-attested entitlement. Not its published state: the
// pre-negotiated transceivers deliver their tracks when the connection is
// set up, long before the sender turns anything on. LiveKit rooms skip this
// check: the SFU refuses unauthorized track sources at publish time, and its
// subscriptions can arrive ahead of the roster broadcast.
//
// Mic audio arrives with the sender's stream attached; the pre-negotiated
// screen-audio transceiver delivers a bare track (see RemoteStreamRegistry).
export function remoteTrackAllowed(
  room,
  userId,
  track,
  streams,
  { mesh = false } = {}
) {
  if (!room || !track) {
    return false;
  }

  const isScreenAudio = track.kind === "audio" && !streams?.length;
  if (track.kind === "video" || isScreenAudio) {
    if (!room.video_enabled) {
      return false;
    }

    if (
      mesh &&
      !senderEntitledToMedia(room, userId, { screenOnly: isScreenAudio })
    ) {
      return false;
    }
  }

  return participantCanSpeak(room, userId);
}

// Mesh carries camera and screen on one video m-line, so the video track is
// allowed for a sender entitled to either; screen audio needs screen sharing.
export function participantEntitledToMedia(
  participant,
  { screenOnly = false } = {}
) {
  if (!participant) {
    return false;
  }

  if (screenOnly) {
    return !!participant.can_screen_share;
  }

  return !!(participant.can_publish_video || participant.can_screen_share);
}

function senderEntitledToMedia(room, userId, options) {
  return participantEntitledToMedia(
    (room.active_participants || []).find(
      (p) => Number(p?.id) === Number(userId)
    ),
    options
  );
}
