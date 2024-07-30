moment.tz.link(["Asia/Kolkata|IST", "Asia/Seoul|KST", "Asia/Tokyo|JST"]);
const timezoneNames = moment.tz.names();

function addLocalDate(attributes, state, buffer, applyDataAttributes) {
  if (attributes.timezone) {
    if (!timezoneNames.includes(attributes.timezone)) {
      delete attributes.timezone;
    }
  }

  if (attributes.displayedTimezone) {
    if (!timezoneNames.includes(attributes.displayedTimezone)) {
      delete attributes.displayedTimezone;
    }
  }

  if (attributes.timezones) {
    attributes.timezones = attributes.timezones
      .split("|")
      .filter((tz) => timezoneNames.includes(tz))
      .join("|");
  }

  const dateTime = moment.tz(
    [attributes._default || attributes.date, attributes.time]
      .filter(Boolean)
      .join("T"),
    attributes.timezone || "Etc/UTC"
  );

  const emailFormat =
    state.md.options.discourse.datesEmailFormat || moment.defaultFormat;

  attributes.emailPreview = `${dateTime.utc().format(emailFormat)} UTC`;

  let token = new state.Token("span_open", "span", 1);
  token.attrs = [["class", "discourse-local-date"]];
  applyDataAttributes(token, attributes, "date");
  buffer.push(token);

  token = new state.Token("text", "", 0);
  token.content = dateTime.utc().format(attributes.format);
  buffer.push(token);

  token = new state.Token("span_close", "span", -1);
  buffer.push(token);
}

function date(buffer, matches, state, { parseBBCodeTag, applyDataAttributes }) {
  const parsed = parseBBCodeTag(matches[0], 0, matches[0].length);

  if (parsed?.tag === "date") {
    addLocalDate(parsed.attrs, state, buffer, applyDataAttributes);
  } else {
    let token = new state.Token("text", "", 0);
    token.content = matches[0];
    buffer.push(token);
  }
}

function range(
  buffer,
  matches,
  state,
  { parseBBCodeTag, applyDataAttributes }
) {
  let token;
  const parsed = parseBBCodeTag(matches[0], 0, matches[0].length);

  if (parsed?.tag === "date-range") {
    if (parsed.attrs.from) {
      const { from, ...attributes } = { ...parsed.attrs, range: "from" };
      delete attributes.to;
      [attributes.date, attributes.time] = from.split("T");
      addLocalDate(attributes, state, buffer, applyDataAttributes);
    }

    if (parsed.attrs.from && parsed.attrs.to) {
      token = new state.Token("text", "", 0);
      token.content = "→";
      buffer.push(token);
    }

    if (parsed.attrs.to) {
      const { to, ...attributes } = { ...parsed.attrs, range: "to" };
      delete attributes.from;
      [attributes.date, attributes.time] = to.split("T");
      addLocalDate(attributes, state, buffer, applyDataAttributes);
    }
  } else {
    token = new state.Token("text", "", 0);
    token.content = matches[0];
    buffer.push(token);
  }
}

export function setup(helper) {
  helper.allowList([
    "span.discourse-local-date",
    "span[aria-label]",
    "span[data-calendar]",
    "span[data-countdown]",
    "span[data-date]",
    "span[data-displayed-timezone]",
    "span[data-email-preview]",
    "span[data-format]",
    "span[data-recurring]",
    "span[data-time]",
    "span[data-timezone]",
    "span[data-timezones]",
  ]);

  helper.registerOptions((opts, siteSettings) => {
    opts.datesEmailFormat = siteSettings.discourse_local_dates_email_format;

    opts.features["discourse-local-dates"] =
      !!siteSettings.discourse_local_dates_enabled;
  });

  helper.registerPlugin((md) => {
    md.core.textPostProcess.ruler.push("date", {
      matcher: /\[date=.+?\]/,
      onMatch: date,
    });

    md.core.textPostProcess.ruler.push("date-range", {
      matcher: /\[date-range .+?\]/,
      onMatch: range,
    });
  });
}
