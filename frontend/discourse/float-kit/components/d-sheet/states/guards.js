export const GUARD_NAMES = Object.freeze({
  NOT_SKIP_CLOSING: "notSkipClosing",
  NOT_SKIP_OPENING: "notSkipOpening",
  NOT_SKIP_CLOSING_MSG: "notSkipClosingMsg",
  NOT_SKIP_OPENING_MSG: "notSkipOpeningMsg",
  OPENING_CLOSE_REQUESTED: "openingCloseRequested",
  SKIP_OPENING: "skipOpening",
  SKIP_CLOSING: "skipClosing",
  SAFE_TO_UNMOUNT: "safeToUnmount",
  SAFE_TO_UNMOUNT_AND_NOT_SKIP_OPENING: "safeToUnmountAndNotSkipOpening",
});

export const GUARDS = {
  [GUARD_NAMES.NOT_SKIP_CLOSING]: (previousStates, message) =>
    !previousStates.includes("skipClosing:true") && !message.skipClosing,
  [GUARD_NAMES.NOT_SKIP_OPENING]: (previousStates, message) =>
    !previousStates.includes("skipOpening:true") && !message.skipOpening,
  [GUARD_NAMES.NOT_SKIP_CLOSING_MSG]: (_previousStates, message) =>
    !message.skipClosing,
  [GUARD_NAMES.NOT_SKIP_OPENING_MSG]: (_previousStates, message) =>
    !message.skipOpening,
  [GUARD_NAMES.OPENING_CLOSE_REQUESTED]: (previousStates) =>
    previousStates.includes("openness:opening.evaluateCloseMessage:true"),
  [GUARD_NAMES.SKIP_OPENING]: (previousStates, message) =>
    previousStates.includes("skipOpening:true") || message.skipOpening,
  [GUARD_NAMES.SKIP_CLOSING]: (previousStates, message) =>
    previousStates.includes("skipClosing:true") || message.skipClosing,
  [GUARD_NAMES.SAFE_TO_UNMOUNT]: (previousStates) =>
    previousStates.includes("openness:closed.status:safe-to-unmount"),
  [GUARD_NAMES.SAFE_TO_UNMOUNT_AND_NOT_SKIP_OPENING]: (
    previousStates,
    message
  ) =>
    previousStates.includes("openness:closed.status:safe-to-unmount") &&
    !previousStates.includes("skipOpening:true") &&
    !message.skipOpening,
};
