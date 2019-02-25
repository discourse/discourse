import { parseBBCodeTag } from "pretty-text/engines/discourse-markdown/bbcode-block";

function addLocalDate(buffer, matches, state) {
  let token;

  let config = {
    date: null,
    time: null,
    timezone: null,
    format: null,
    timezones: null,
    displayedTimezone: null
  };

  let parsed = parseBBCodeTag(
    "[date date" + matches[1] + "]",
    0,
    matches[1].length + 11
  );

  config.date = parsed.attrs.date;
  config.format = parsed.attrs.format;
  config.calendar = parsed.attrs.calendar;
  config.time = parsed.attrs.time;
  config.timezone = parsed.attrs.timezone;
  config.recurring = parsed.attrs.recurring;
  config.timezones = parsed.attrs.timezones;
  config.displayedTimezone = parsed.attrs.displayedTimezone;

  token = new state.Token("span_open", "span", 1);
  token.attrs = [["data-date", state.md.utils.escapeHtml(config.date)]];

  if (!config.date.match(/\d{4}-\d{2}-\d{2}/)) {
    closeBuffer(buffer, state, moment.invalid().format());
    return;
  }

  if (config.time && !config.time.match(/\d{2}:\d{2}(?::\d{2})?/)) {
    closeBuffer(buffer, state, moment.invalid().format());
    return;
  }

  let dateTime = config.date;
  if (config.time) {
    token.attrs.push(["data-time", state.md.utils.escapeHtml(config.time)]);
    dateTime = `${dateTime} ${config.time}`;
  }

  if (!moment(dateTime).isValid()) {
    closeBuffer(buffer, state, moment.invalid().format());
    return;
  }

  token.attrs.push(["class", "discourse-local-date"]);

  if (config.format) {
    token.attrs.push(["data-format", state.md.utils.escapeHtml(config.format)]);
  }

  if (config.calendar) {
    token.attrs.push([
      "data-calendar",
      state.md.utils.escapeHtml(config.calendar)
    ]);
  }

  if (
    config.displayedTimezone &&
    moment.tz.names().includes(config.displayedTimezone)
  ) {
    token.attrs.push([
      "data-displayed-timezone",
      state.md.utils.escapeHtml(config.displayedTimezone)
    ]);
  }

  if (config.timezones) {
    const timezones = config.timezones.split("|").filter(timezone => {
      return moment.tz.names().includes(timezone);
    });

    token.attrs.push([
      "data-timezones",
      state.md.utils.escapeHtml(timezones.join("|"))
    ]);
  }

  if (config.timezone && moment.tz.names().includes(config.timezone)) {
    token.attrs.push([
      "data-timezone",
      state.md.utils.escapeHtml(config.timezone)
    ]);
    dateTime = moment.tz(dateTime, config.timezone);
  } else {
    dateTime = moment.utc(dateTime);
  }

  if (config.recurring) {
    token.attrs.push([
      "data-recurring",
      state.md.utils.escapeHtml(config.recurring)
    ]);
  }

  buffer.push(token);

  const formattedDateTime = dateTime
    .tz("Etc/UTC")
    .format(
      state.md.options.discourse.datesEmailFormat || moment.defaultFormat
    );
  token.attrs.push(["data-email-preview", `${formattedDateTime} UTC`]);

  closeBuffer(buffer, state, dateTime.utc().format(config.format));
}

function closeBuffer(buffer, state, text) {
  let token;

  token = new state.Token("text", "", 0);
  token.content = text;
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
    opts.datesEmailFormat = siteSettings.discourse_local_dates_email_format;

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
