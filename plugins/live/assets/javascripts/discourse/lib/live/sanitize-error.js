const MAX_MESSAGE_LENGTH = 200;

function sanitizeMessage(message) {
  // Payloads and additional lines can contain session descriptions or server responses.
  return message
    .replace(/\s*(?:[\r\n{]|\[)[\s\S]*/, " [FILTERED]")
    .replace(
      /\b(?:sdp|candidate|transcript|response body)\s*[:=][\s\S]*/gi,
      "[FILTERED]"
    )
    .replace(/\b(?:https?|wss?|turns?|stun):[^\s<>"']+/gi, "[FILTERED]")
    .replace(/\bBearer\s+[^\s,;"']+/gi, "[FILTERED]")
    .replace(/\beyJ[\w-]+\.[\w-]+(?:\.[\w-]+)?\b/g, "[FILTERED]")
    .replace(
      /\b(?:access[_-]?token|token|api[_-]?key|secret|password|credential|authorization)\b["']?\s*[:=]\s*(?:"[^"\r\n]*"|'[^'\r\n]*'|[^\s,;]+)/gi,
      "[FILTERED]"
    )
    .replace(/\b(?:\d{1,3}\.){3}\d{1,3}\b/g, "[FILTERED]")
    .replace(/\b(?:[\da-f]{0,4}:){2,}[\da-f:.]*(?:%[\w-]+)?/gi, "[FILTERED]")
    .replace(/\b[\w.+-]+@[\w.-]+\.[a-z]{2,}\b/gi, "[FILTERED]")
    .slice(0, MAX_MESSAGE_LENGTH);
}

/** Extracts bounded diagnostics without serializing errors, stacks, or nested payloads. */
export default function sanitizeError(error) {
  if (!error) {
    return;
  }

  const details = {};
  if (
    typeof error.name === "string" &&
    /^[A-Za-z][A-Za-z0-9]{0,63}$/.test(error.name)
  ) {
    details.name = error.name;
  }
  if (
    (typeof error.code === "number" && Number.isFinite(error.code)) ||
    (typeof error.code === "string" &&
      /^[A-Z][A-Z0-9_]{0,63}$/.test(error.code))
  ) {
    details.code = error.code;
  }

  const message = typeof error === "string" ? error : error.message;
  if (typeof message === "string") {
    details.message = sanitizeMessage(message);
  }

  return Object.keys(details).length ? details : undefined;
}
