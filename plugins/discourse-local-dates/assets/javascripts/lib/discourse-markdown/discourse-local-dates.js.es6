import { parseBBCodeTag } from "pretty-text/engines/discourse-markdown/bbcode-block";

function addLocalDate(buffer, matches, state) {
  let token;

  let config = {
    date: null,
    time: null,
    format: "YYYY-MM-DD HH:mm:ss",
    timezones: ""
  };

  let parsed = parseBBCodeTag(
    "[date date" + matches[1] + "]",
    0,
    matches[1].length + 11
  );

  config.date = parsed.attrs.date;
  config.time = parsed.attrs.time;
  config.forceTimezone = parsed.attrs.forceTimezone;
  config.recurring = parsed.attrs.recurring;
  config.format = parsed.attrs.format || config.format;
  config.timezones = parsed.attrs.timezones || config.timezones;

  token = new state.Token("span_open", "span", 1);
  token.attrs = [
    ["class", "discourse-local-date"],
    ["data-date", state.md.utils.escapeHtml(config.date)],
    ["data-time", state.md.utils.escapeHtml(config.time)],
    ["data-format", state.md.utils.escapeHtml(config.format)],
    ["data-timezones", state.md.utils.escapeHtml(config.timezones)]
  ];

  if (config.forceTimezone) {
    token.attrs.push([
      "data-force-timezone",
      state.md.utils.escapeHtml(config.forceTimezone)
    ]);
  }

  if (config.recurring) {
    token.attrs.push([
      "data-recurring",
      state.md.utils.escapeHtml(config.recurring)
    ]);
  }
  buffer.push(token);

  const previews = config.timezones
    .split("|")
    .filter(t => t)
    .map(timezone => {
      const dateTime = moment
        .utc(`${config.date} ${config.time}`, "YYYY-MM-DD HH:mm:ss")
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
