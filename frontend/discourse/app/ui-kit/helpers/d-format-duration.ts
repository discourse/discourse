import { trustHTML } from "@ember/template";
import { durationTiny } from "discourse/lib/formatter";

/**
 * Renders a length of time in the tiny format, such as "2m".
 *
 * @param seconds - The length in seconds. Anything else renders as a dash.
 * @returns The trusted markup.
 */
export default function dFormatDuration(seconds?: number | null) {
  return trustHTML(durationTiny(seconds));
}
