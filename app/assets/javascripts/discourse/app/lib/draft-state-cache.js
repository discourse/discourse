// In-memory draft state store keyed by draftKey. No HTTP calls.
// Values: { hasDraft: boolean, postId?: number, action?: string }
const _store = new Map();

export function invalidateDraftState(draftKey) {
  if (draftKey) {
    _store.delete(draftKey);
  }
}

export function setDraftFromTopic(topic) {
  const key = topic?.draft_key;
  if (!key) {
    return;
  }
  if (topic.draft) {
    let payload;
    try {
      payload = JSON.parse(topic.draft);
    } catch {
      payload = null;
    }
    _store.set(key, {
      hasDraft: true,
      postId: payload?.postId,
      action: payload?.action,
    });
  } else {
    _store.delete(key);
  }
}

export function setDraftSaved(draftKey, { postId, action } = {}) {
  if (!draftKey) {
    return;
  }
  _store.set(draftKey, { hasDraft: true, postId, action });
}

export function setDraftDestroyed(draftKey) {
  if (!draftKey) {
    return;
  }
  _store.delete(draftKey);
}

export function hasDraft(draftKey) {
  return draftKey ? Boolean(_store.get(draftKey)?.hasDraft) : false;
}

export function matchesPost(draftKey, postId) {
  if (!draftKey || !postId) {
    return false;
  }
  const info = _store.get(draftKey);
  return Boolean(info?.hasDraft && info.postId && info.postId === postId);
}
