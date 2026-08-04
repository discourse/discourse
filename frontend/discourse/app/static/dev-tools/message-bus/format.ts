import { durationTiny } from "discourse/lib/formatter";
import { i18n } from "discourse-i18n";
import type { ObservedMessage } from "./instrumentation";

interface MessageFormat {
  bytes: number;
  preview: string;
}

const messageFormats = new WeakMap<ObservedMessage, MessageFormat>();
const textEncoder = new TextEncoder();

/** Formats a timestamp as a compact age relative to the supplied clock. */
export function relativeShortTime(
  timestamp: number | null | undefined,
  now: number
): string {
  if (timestamp == null) {
    return "";
  }

  const seconds = Math.max(0, Math.round((now - timestamp) / 1000));

  return seconds < 60
    ? i18n("dates.tiny.x_seconds", { count: seconds })
    : durationTiny(seconds);
}

/** Pretty-prints JSON-compatible data and falls back to its string form. */
export function prettyJson(data: unknown): string {
  try {
    return JSON.stringify(data, null, 2) ?? String(data);
  } catch {
    return String(data);
  }
}

/** Reduces a stack frame to its caller name, file name, and line number. */
export function shortSource(frame: string | null | undefined): string | null {
  if (frame == null) {
    return null;
  }

  const trimmed = frame.trim();
  const match = trimmed.match(/^at\s+(?:(.*?)\s+\()?(.+):(\d+):\d+\)?$/);

  if (!match) {
    return trimmed;
  }

  const [, caller, path, line] = match;
  const file = path.slice(path.lastIndexOf("/") + 1);
  return caller ? `${caller} (${file}:${line})` : `${file}:${line}`;
}

function formatMessage(message: ObservedMessage): MessageFormat {
  let formatted = messageFormats.get(message);

  if (!formatted) {
    let preview: string;

    try {
      preview = JSON.stringify(message.data) ?? String(message.data);
    } catch {
      preview = String(message.data);
    }

    preview = preview.replaceAll("\n", " ");
    formatted = { preview, bytes: textEncoder.encode(preview).byteLength };
    messageFormats.set(message, formatted);
  }

  return formatted;
}

/** Returns a cached, single-line serialization of a captured payload. */
export function messagePreview(message: ObservedMessage): string {
  return formatMessage(message).preview;
}

/** Returns the cached UTF-8 byte length of a captured payload. */
export function messageBytes(message: ObservedMessage): number {
  return formatMessage(message).bytes;
}

/** Renders a millisecond duration without float measurement noise. */
export function formatMs(value: number): string {
  return value >= 100
    ? Math.round(value).toString()
    : value.toFixed(1).replace(/\.0$/, "");
}
