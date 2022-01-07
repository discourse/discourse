import { parseBBCodeTag } from "pretty-text/engines/discourse-markdown/bbcode-block";

const timezoneNames = moment.tz.names();

function addSingleLocalDate(buffer, state, config) {
  let token = new state.Token("span_open", "span", 1);
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

  if (config.countdown) {
    token.attrs.push([
      "data-countdown",
      state.md.utils.escapeHtml(config.countdown),
    ]);
  }

  if (config.calendar) {
    token.attrs.push([
      "data-calendar",
      state.md.utils.escapeHtml(config.calendar),
    ]);
  }
  if (config.range) {
    token.attrs.push(["data-range", true]);
  }

  if (
    config.displayedTimezone &&
    timezoneNames.includes(config.displayedTimezone)
  ) {
    token.attrs.push([
      "data-displayed-timezone",
      state.md.utils.escapeHtml(config.displayedTimezone),
    ]);
  }

  if (config.timezones) {
    const timezones = config.timezones.split("|").filter((timezone) => {
      return timezoneNames.includes(timezone);
    });

    token.attrs.push([
      "data-timezones",
      state.md.utils.escapeHtml(timezones.join("|")),
    ]);
  }

  if (config.timezone && timezoneNames.includes(config.timezone)) {
    token.attrs.push([
      "data-timezone",
      state.md.utils.escapeHtml(config.timezone),
    ]);
    dateTime = moment.tz(dateTime, config.timezone);
  } else {
    dateTime = moment.utc(dateTime);
  }

  if (config.recurring) {
    token.attrs.push([
      "data-recurring",
      state.md.utils.escapeHtml(config.recurring),
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

function defaultDateConfig() {
  return {
    date: null,
    time: null,
    timezone: null,
    format: null,
    timezones: null,
    displayedTimezone: null,
    countdown: null,
    range: false,
  };
}

function parseTagAttributes(tag) {
  const matchString = tag.replace(/‘|’|„|“|«|»|”/g, '"');

  return parseBBCodeTag(
    "[date date" + matchString + "]",
    0,
    matchString.length + 12
  );
}

function addLocalDate(buffer, matches, state) {
  let config = defaultDateConfig();

  const parsed = parseTagAttributes(matches[1]);

  config.date = parsed.attrs.date;
  config.format = parsed.attrs.format;
  config.calendar = parsed.attrs.calendar;
  config.time = parsed.attrs.time;
  config.timezone = (parsed.attrs.timezone || "").trim();
  config.recurring = parsed.attrs.recurring;
  config.timezones = parsed.attrs.timezones;
  config.displayedTimezone = parsed.attrs.displayedTimezone;
  config.countdown = parsed.attrs.countdown;
  addSingleLocalDate(buffer, state, config);
}

function addLocalRange(buffer, matches, state) {
  let config = defaultDateConfig();
  let date, time;
  const parsed = parseTagAttributes(matches[1]);

  config.format = parsed.attrs.format;
  config.calendar = parsed.attrs.calendar;
  config.timezone = (parsed.attrs.timezone || "").trim();
  config.recurring = parsed.attrs.recurring;
  config.timezones = parsed.attrs.timezones;
  config.displayedTimezone = parsed.attrs.displayedTimezone;
  config.countdown = parsed.attrs.countdown;
  config.range = parsed.attrs.from && parsed.attrs.to;

  if (parsed.attrs.from) {
    [date, time] = parsed.attrs.from.split("T");
    config.date = date;
    config.time = time;
    addSingleLocalDate(buffer, state, config);
  }
  if (config.range) {
    closeBuffer(buffer, state, "→");
  }
  if (parsed.attrs.to) {
    [date, time] = parsed.attrs.to.split("T");
    config.date = date;
    config.time = time;
    addSingleLocalDate(buffer, state, config);
  }
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
  helper.allowList([
    "span.discourse-local-date",
    "span[aria-label]",
    "span[data-date]",
    "span[data-time]",
    "span[data-format]",
    "span[data-countdown]",
    "span[data-calendar]",
    "span[data-displayed-timezone]",
    "span[data-timezone]",
    "span[data-timezones]",
    "span[data-recurring]",
    "span[data-email-preview]",
  ]);

  helper.registerOptions((opts, siteSettings) => {
    opts.datesEmailFormat = siteSettings.discourse_local_dates_email_format;

    opts.features[
      "discourse-local-dates"
    ] = !!siteSettings.discourse_local_dates_enabled;
  });

  helper.registerPlugin((md) => {
    const rule = {
      matcher: /\[date(=.+?)\]/,
      onMatch: addLocalDate,
    };

    md.core.textPostProcess.ruler.push("discourse-local-dates", rule);
  });

  helper.registerPlugin((md) => {
    const rule = {
      matcher: /\[date-range(.+?)\]/,
      onMatch: addLocalRange,
    };

    md.core.textPostProcess.ruler.push("discourse-local-dates", rule);
  });
}
