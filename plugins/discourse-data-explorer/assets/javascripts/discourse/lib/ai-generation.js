export const AI_GENERATION_CHANNEL_PREFIX =
  "/discourse-data-explorer/queries/ai-generation";
export const AI_GENERATION_TIMEOUT_MS = 60000;

export function subscribeToAiGeneration({
  messageBus,
  generationId,
  onComplete,
  onError,
  onTimeout,
}) {
  const channel = `${AI_GENERATION_CHANNEL_PREFIX}/${generationId}`;
  let timerId = null;
  let torndown = false;

  const teardown = () => {
    if (torndown) {
      return;
    }
    torndown = true;
    messageBus.unsubscribe(channel, handler);
    clearTimeout(timerId);
  };

  const handler = (data) => {
    if (data.generation_id !== generationId) {
      return;
    }
    if (data.status === "complete") {
      teardown();
      onComplete?.(data);
    } else if (data.status === "error") {
      teardown();
      onError?.(data);
    }
  };

  messageBus.subscribe(channel, handler, -1);
  timerId = setTimeout(() => {
    teardown();
    onTimeout?.();
  }, AI_GENERATION_TIMEOUT_MS);

  return teardown;
}
