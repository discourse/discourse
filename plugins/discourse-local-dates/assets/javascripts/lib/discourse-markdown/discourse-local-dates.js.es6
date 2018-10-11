import { parseBBCodeTag } from "pretty-text/engines/discourse-markdown/bbcode-block";

function addLocalDate(buffer, matches, state) {
  let token;

  let config = {
    date: null,
    time: null,
    forceTimezone: null,
    format: "YYYY-MM-DD HH:mm:ss",
    timezones: "Etc/UTC"
  };

  let parsed = parseBBCodeTag(
    "[date date" + matches[1] + "]",
    0,
    matches[1].length + 11
  );

  config.date = parsed.attrs.date;
  config.time = parsed.attrs.time;
  config.forceTimezone = parsed.attrs.forceTimezone || parsed.attrs.timezone;
  config.recurring = parsed.attrs.recurring;
  config.format = parsed.attrs.format || config.format;
  config.timezones = parsed.attrs.timezones || config.timezones;

  token = new state.Token("span_open", "span", 1);
  token.attrs = [
    ["class", "discourse-local-date"],
    ["data-date", state.md.utils.escapeHtml(config.date)],
    ["data-format", state.md.utils.escapeHtml(config.format)],
    ["data-timezones", state.md.utils.escapeHtml(config.timezones)]
  ];

  if (config.time) {
    token.attrs.push([
      "data-time",
      state.md.utils.escapeHtml(config.time)
    ]);
  }

  let dateTime;
  if (config.forceTimezone) {
    token.attrs.push([
      "data-force-timezone",
      state.md.utils.escapeHtml(config.forceTimezone)
    ]);
    dateTime = moment.tz(`${config.date} ${config.time}`, config.forceTimezone);
  } else {
    dateTime = moment.utc(`${config.date} ${config.time}`);
  }

  if (config.recurring) {
    token.attrs.push([
      "data-recurring",
      state.md.utils.escapeHtml(config.recurring)
    ]);
  }
  buffer.push(token);

  let emailPreview;
  const emailTimezone = config.timezones.split("|")[0];
  const formattedDateTime = dateTime.tz(emailTimezone).format(config.format);
  const formattedTimezone = emailTimezone.replace("/", ": ").replace("_", " ");

  if (formattedDateTime.match(/TZ/)) {
    emailPreview = formattedDateTime.replace("TZ", formattedTimezone);
  } else {
    emailPreview = `${formattedDateTime} (${formattedTimezone})`;
  }

  token.attrs.push(["data-email-preview", emailPreview]);

  token = new state.Token("text", "", 0);
  token.content = dateTime.utc().format(config.format);
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
