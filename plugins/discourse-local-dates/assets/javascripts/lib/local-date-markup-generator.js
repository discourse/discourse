import { isEmpty } from "@ember/utils";

export default function generateDateMarkup(
  fromDateTime,
  options,
  isRange,
  toDateTime
) {
  let text = ``;

  if (isRange) {
    let from = [fromDateTime.date, fromDateTime.time]
      .filter((element) => !isEmpty(element))
      .join("T");
    let to = [toDateTime.date, toDateTime.time]
      .filter((element) => !isEmpty(element))
      .join("T");
    text += `[date-range from=${from} to=${to}`;
  } else {
    text += `[date=${fromDateTime.date}`;
  }

  if (fromDateTime.time && !isRange) {
    text += ` time=${fromDateTime.time}`;
  }

  if (fromDateTime.format && fromDateTime.format.length) {
    text += ` format="${fromDateTime.format}"`;
  }

  if (options.timezone) {
    text += ` timezone="${options.timezone}"`;
  }

  if (options.countdown) {
    text += ` countdown="${options.countdown}"`;
  }

  if (options.displayedTimezone) {
    text += ` displayedTimezone="${options.displayedTimezone}"`;
  }

  if (options.timezones && options.timezones.length) {
    if (Array.isArray(options.timezones)) {
      text += ` timezones="${options.timezones.join("|")}"`;
    } else {
      text += ` timezones="${options.timezones}"`;
    }
  }

  if (options.recurring && !isRange) {
    text += ` recurring="${options.recurring}"`;
  }

  text += `]`;

  return text;
}
