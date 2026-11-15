import { trustHTML } from "@ember/template";
import type { AutoUpdatingRelativeAgeOptions } from "discourse/lib/formatter";
import { autoUpdatingRelativeAge } from "discourse/lib/formatter";

/**
 * Renders a relative age that refreshes itself, titled with the long date
 * unless `title` is false.
 *
 * @param dt - The date, as a `Date`, a timestamp or a date string.
 * @param params - The named arguments, passed on to `autoUpdatingRelativeAge`.
 * @returns The trusted markup.
 */
export default function dAgeWithTooltip(
  dt: Date | number | string,
  params: AutoUpdatingRelativeAgeOptions = {}
) {
  return trustHTML(
    autoUpdatingRelativeAge(new Date(dt), {
      ...params,
      title: params.title ?? true,
    })
  );
}
