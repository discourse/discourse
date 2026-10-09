export const NEW_LOGS_POLL_INTERVAL_MS = 20_000;
export const NEW_LOGS_POLL_BACKOFF_STEP_MS = 10_000;
export const NEW_LOGS_POLL_MAX_INTERVAL_MS = 60_000;

export function newLogsPollIntervalMs(emptyPollCount = 0) {
  const steps = Math.floor(
    (NEW_LOGS_POLL_MAX_INTERVAL_MS - NEW_LOGS_POLL_INTERVAL_MS) /
      NEW_LOGS_POLL_BACKOFF_STEP_MS
  );
  return (
    NEW_LOGS_POLL_INTERVAL_MS +
    Math.min(Math.max(emptyPollCount, 0), steps) * NEW_LOGS_POLL_BACKOFF_STEP_MS
  );
}
