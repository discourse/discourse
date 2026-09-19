const MAX_PENDING_OPTIMISTIC_UPDATES = 100;
const OPTIMISTIC_UPDATE_TTL = 30_000;
const pendingOptimisticUpdates = new Map();

function removeOptimisticPostUpdate(token) {
  const update = pendingOptimisticUpdates.get(token);
  if (!update) {
    return;
  }

  clearTimeout(update.timeout);
  pendingOptimisticUpdates.delete(token);
}

export function registerOptimisticPostUpdate(token) {
  if (pendingOptimisticUpdates.has(token)) {
    removeOptimisticPostUpdate(token);
  } else if (pendingOptimisticUpdates.size >= MAX_PENDING_OPTIMISTIC_UPDATES) {
    removeOptimisticPostUpdate(pendingOptimisticUpdates.keys().next().value);
  }

  const update = {};
  pendingOptimisticUpdates.set(token, update);

  return {
    startExpiration() {
      if (!pendingOptimisticUpdates.has(token) || update.timeout) {
        return;
      }

      update.timeout = setTimeout(
        () => removeOptimisticPostUpdate(token),
        OPTIMISTIC_UPDATE_TTL
      );
    },
    unregister: () => removeOptimisticPostUpdate(token),
  };
}

export function consumeOptimisticPostUpdate(token) {
  if (!token || !pendingOptimisticUpdates.has(token)) {
    return false;
  }

  removeOptimisticPostUpdate(token);
  return true;
}
