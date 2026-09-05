// The inviter username carried by an invite URL the user arrived through
// (/voice/r/:slug/invited-by/:username), held until they actually join that
// room so the server credits the inviter on a real join, not a page view.
let pendingInviteRef = null;

export function setPendingInviteRef(roomSlug, username) {
  pendingInviteRef = { roomSlug, username };
}

// Returns the inviter username when the pending ref belongs to this room,
// clearing it either way once the room matches.
export function consumePendingInviteRef(room) {
  if (!pendingInviteRef || pendingInviteRef.roomSlug !== room.slug) {
    return null;
  }
  const { username } = pendingInviteRef;
  pendingInviteRef = null;
  return username;
}
