const MAX_PENDING_OPTIMISTIC_UPDATES = 100;
const pendingOptimisticUpdates = new Map();

function removeOptimisticPostUpdate(token) {
  const update = pendingOptimisticUpdates.get(token);
  if (!update) {
    return;
  }

  pendingOptimisticUpdates.delete(token);
  update.resolve();
}

export function registerOptimisticPostUpdate(token) {
  if (pendingOptimisticUpdates.has(token)) {
    removeOptimisticPostUpdate(token);
  } else if (pendingOptimisticUpdates.size >= MAX_PENDING_OPTIMISTIC_UPDATES) {
    removeOptimisticPostUpdate(pendingOptimisticUpdates.keys().next().value);
  }

  let resolve;
  const reconciled = new Promise((promiseResolve) => {
    resolve = promiseResolve;
  });
  const update = {
    complete() {
      if (update.completed) {
        return;
      }

      update.completed = true;
      resolve();
      queueMicrotask(() => {
        if (pendingOptimisticUpdates.get(token) === update) {
          pendingOptimisticUpdates.delete(token);
        }
      });
    },
    completed: false,
    resolve,
  };
  pendingOptimisticUpdates.set(token, update);

  return {
    reconciled,
    unregister: () => removeOptimisticPostUpdate(token),
  };
}

export function consumeOptimisticPostUpdate(token) {
  const update = token && pendingOptimisticUpdates.get(token);
  if (!update) {
    return;
  }

  return update.complete;
}
