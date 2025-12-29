import { isEmpty } from "@ember/utils";
import { buildBBCodeAttrs } from "discourse/lib/text";

export default function generateDateMarkup(
  fromDateTime,
  options,
  isRange,
  toDateTime
) {
  const attrs = {};

  if (!isRange) {
    attrs.time = fromDateTime.time;
  }

  attrs.format = fromDateTime.format;
  attrs.timezone = options.timezone;
  attrs.countdown = options.countdown;
  attrs.displayedTimezone = options.displayedTimezone;
  attrs.timezones = Array.isArray(options.timezones)
    ? options.timezones.join("|")
    : options.timezones;

  if (!isRange) {
    attrs.recurring = options.recurring;
  }

  const attrsStr = buildBBCodeAttrs(attrs);
  const suffix = attrsStr ? ` ${attrsStr}` : "";

  if (isRange) {
    const from = [fromDateTime.date, fromDateTime.time]
      .filter((el) => !isEmpty(el))
      .join("T");
    const to = [toDateTime.date, toDateTime.time]
      .filter((el) => !isEmpty(el))
      .join("T");
    return `[date-range from=${from} to=${to}${suffix}]`;
  }

  return `[date=${fromDateTime.date}${suffix}]`;
}
