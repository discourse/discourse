import { parseBBCodeTag } from "pretty-text/engines/discourse-markdown/bbcode-block";

function addLocalDate(buffer, matches, state) {
  let token;

  let config = {
    date: null,
    time: null,
    format: "YYYY-MM-DD HH:mm",
    timezones: ""
  };

  let parsed = parseBBCodeTag(
    "[date date" + matches[1] + "]",
    0,
    matches[1].length + 11
  );

  config.date = parsed.attrs.date;
  config.time = parsed.attrs.time;
  config.recurring = parsed.attrs.recurring;
  config.format = parsed.attrs.format || config.format;
  config.timezones = parsed.attrs.timezones || config.timezones;

  token = new state.Token("span_open", "span", 1);
  token.attrs = [
    ["class", "discourse-local-date"],
    ["data-date", config.date],
    ["data-time", config.time],
    ["data-format", config.format],
    ["data-timezones", config.timezones]
  ];
  if (config.recurring) {
    token.attrs.push(["data-recurring", config.recurring]);
  }
  buffer.push(token);

  const previews = config.timezones
    .split("|")
    .filter(t => t)
    .map(timezone => {
      const dateTime = moment
        .utc(`${config.date} ${config.time}`, "YYYY-MM-DD HH:mm")
        .tz(timezone)
        .format(config.format);

      const formattedTimezone = timezone.replace("/", ": ").replace("_", " ");

      if (dateTime.match(/TZ/)) {
        return dateTime.replace("TZ", formattedTimezone);
      } else {
        return `${dateTime} (${formattedTimezone})`;
      }
    });

  token.attrs.push(["data-email-preview", previews[0]]);

  token = new state.Token("text", "", 0);
  token.content = previews.join(", ");
  buffer.push(token);

  token = new state.Token("span_close", "span", -1);
  buffer.push(token);
}

export function setup(helper) {
  helper.whiteList([
    "span.discourse-local-date",
    "span[data-*]",
    "span[title]"
  ]);

  helper.registerOptions((opts, siteSettings) => {
    opts.features[
      "discourse-local-dates"
    ] = !!siteSettings.discourse_local_dates_enabled;
  });

  helper.registerPlugin(md => {
    const rule = {
      matcher: /\[date(.+?)\]/,
      onMatch: addLocalDate
    };

    md.core.textPostProcess.ruler.push("discourse-local-dates", rule);
  });
}
