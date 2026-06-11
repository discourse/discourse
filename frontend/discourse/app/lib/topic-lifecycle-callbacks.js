import { isTesting } from "discourse/lib/environment";

const topicLifecycleCallbacks = [];

function dispatchLifecycleError(messageKey, error) {
  if (isTesting()) {
    return;
  }

  document.dispatchEvent(
    new CustomEvent("discourse-error", {
      detail: { messageKey, error },
    })
  );
}

export function registerTopicLifecycleCallback(callback) {
  topicLifecycleCallbacks.push(callback);
}

export function resetTopicLifecycleCallbacks() {
  topicLifecycleCallbacks.length = 0;
}

export function cleanupTopicLifecycleCallbacks(cleanups) {
  const errors = [];

  for (const cleanup of [...cleanups].reverse()) {
    try {
      cleanup();
    } catch (error) {
      errors.push(error);
      dispatchLifecycleError("broken_topic_lifecycle_cleanup_callback", error);
    }
  }

  if (errors.length > 0 && isTesting()) {
    throw errors[0];
  }
}

export function applyTopicLifecycleCallbacks(context) {
  const cleanups = [];
  const errors = [];

  for (const callback of topicLifecycleCallbacks) {
    try {
      const cleanup = callback(context);

      if (typeof cleanup === "function") {
        cleanups.push(cleanup);
      }
    } catch (error) {
      errors.push(error);
      dispatchLifecycleError("broken_topic_entered_callback", error);
    }
  }

  if (errors.length > 0 && isTesting()) {
    cleanupTopicLifecycleCallbacks(cleanups);
    throw errors[0];
  }

  return cleanups;
}
