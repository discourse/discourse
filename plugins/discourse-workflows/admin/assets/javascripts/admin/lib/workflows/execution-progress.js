export function isPending(execution) {
  return execution.status === "pending";
}

export function isRunning(execution) {
  return execution.status === "running";
}

export function isLive(execution) {
  return (
    isPending(execution) ||
    isRunning(execution) ||
    execution.status === "waiting"
  );
}

export function formatDuration(startedAt, finishedAt, currentTime) {
  if (!startedAt || (!finishedAt && !currentTime)) {
    return "—";
  }

  const end = finishedAt ? new Date(finishedAt) : currentTime;
  const milliseconds = Math.max(0, end - new Date(startedAt));

  if (!finishedAt && currentTime) {
    return `${Math.floor(milliseconds / 1000).toFixed(1)}s`;
  }

  return milliseconds < 1000
    ? `${milliseconds}ms`
    : `${(milliseconds / 1000).toFixed(1)}s`;
}
