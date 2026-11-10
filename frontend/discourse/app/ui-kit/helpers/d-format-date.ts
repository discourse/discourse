import { trustHTML } from "@ember/template";
import { autoUpdatingRelativeAge } from "discourse/lib/formatter";

/**
 * Renders a date as a relative age that refreshes itself, in the medium format
 * and titled with the long date by default.
 *
 * @param val - The date, as a `Date`, a timestamp or a date string.
 * @param params - The named arguments.
 * @returns The trusted markup, or `undefined` without a date.
 */
export default function dFormatDate(
  val: Date | number | string | null | undefined,
  params: {
    /** `"true"` keeps "ago" in the age. */
    leaveAgo?: string;

    /** The `relativeAge` format. Defaults to `"medium"`. */
    format?: string;

    /** Leaves out the title. */
    noTitle?: boolean;

    /** Text placed before the age. */
    prefix?: string;
  } = {}
) {
  let leaveAgo,
    format = "medium",
    title = true;

  if (params.leaveAgo) {
    leaveAgo = params.leaveAgo === "true";
  }
  if (params.format) {
    format = params.format;
  }
  if (params.noTitle) {
    title = false;
  }

  if (val) {
    const date = new Date(val);
    return trustHTML(
      autoUpdatingRelativeAge(date, {
        format,
        title,
        leaveAgo,
        prefix: params.prefix,
      })
    );
  }
}
