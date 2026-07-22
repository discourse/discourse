export const MEETING_NOT_STARTED_ERROR_CODE = 3008;

export function serializeZoomError(error) {
  if (!error) {
    return { message: "Unknown Zoom error" };
  }

  if (typeof error === "string") {
    return { message: error };
  }

  // The reason string is what the SDK returns today, the code is the stable
  // identifier.
  const meetingNotStarted =
    error.reason === "Meeting has not started" ||
    error.errorCode === MEETING_NOT_STARTED_ERROR_CODE;

  return {
    name: error.name,
    message: error.message,
    type: error.type,
    reason: error.reason,
    errorCode: error.errorCode,
    status: error.status,
    stack: error.stack,
    meetingNotStarted,
    ...Object.fromEntries(
      Object.entries(error).filter(([, value]) => typeof value !== "function")
    ),
  };
}
