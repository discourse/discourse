// The request-to-speak queue is derived state: raised hands ride the
// participants payload as `hand_raised_at`, so ordering is recomputed from
// the roster instead of being tracked separately.
export function speakQueue(room) {
  if (room?.room_type !== "stage") {
    return [];
  }

  return (room.active_participants || [])
    .filter((participant) => participant?.hand_raised_at)
    .sort(
      (a, b) =>
        a.hand_raised_at - b.hand_raised_at || Number(a.id) - Number(b.id)
    );
}

export function queuePosition(room, userId) {
  const targetId = Number(userId);
  if (!targetId) {
    return null;
  }

  const index = speakQueue(room).findIndex(
    (participant) => Number(participant.id) === targetId
  );
  return index === -1 ? null : index + 1;
}
