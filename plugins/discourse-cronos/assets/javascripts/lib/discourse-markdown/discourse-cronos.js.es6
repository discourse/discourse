import { registerOption } from 'pretty-text/pretty-text';

registerOption((siteSettings, opts) => {
  opts.features['discourse-cronos'] = !!siteSettings.discourse_cronos_enabled;
});

function addcronos(buffer, matches, state) {
  let token;

  let config = {
    date: null,
    time: null,
    format: "YYYY-MM-DD HH:mm",
    timezones: ""
  };

  const options = matches[1].split(";");
  options.forEach((option) => {
    let o = option.split("=");
    config[o[0]] = o[1];
  });

  token = new state.Token('a_open', 'a', 1);
  token.attrs = [
    ['class', 'discourse-cronos'],
    ['data-date', config.date],
    ['data-time', config.time],
    ['data-recurring', config.recurring],
    ['data-format', config.format],
    ['data-timezones', config.timezones],
  ];
  buffer.push(token);

  const previews = config.timezones.split("|").filter(t => t).map(timezone => {
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

  token = new state.Token('text', '', 0);
  token.content = previews.join(", ");
  buffer.push(token);

  token = new state.Token('a_close', 'a', -1);
  buffer.push(token);
}

export function setup(helper) {
  helper.whiteList([
    'a.discourse-cronos',
    'a[data-*]',
    'a[title]'
  ]);

  helper.registerOptions((opts, siteSettings) => {
    opts.features['discourse-cronos'] = !!siteSettings.discourse_cronos_enabled;
  });

  helper.registerPlugin(md => {
    const rule = {
      matcher: /\[discourse-cronos (.*?)\]/,
      onMatch: addcronos
    };

    md.core.textPostProcess.ruler.push('discourse-cronos', rule);
  });
}
