const calendarRule = {
  tag: "calendar",

  before: function (state, info) {
    let wrapperDivToken = state.push("div_calendar_wrap", "div", 1);
    wrapperDivToken.attrs = [["class", "discourse-calendar-wrap"]];

    let headerDivToken = state.push("div_calendar_header", "div", 1);
    headerDivToken.attrs = [["class", "discourse-calendar-header"]];

    let titleH2Token = state.push("h2_open", "h2", 1);
    titleH2Token.attrs = [["class", "discourse-calendar-title"]];
    state.push("h2_close", "h2", -1);

    let timezoneWrapToken = state.push("span_open", "span", 1);
    timezoneWrapToken.attrs = [["class", "discourse-calendar-timezone-wrap"]];
    if (info.attrs.tzPicker === "true") {
      _renderTimezonePicker(state);
    }
    state.push("span_close", "span", -1);

    state.push("div_calendar_header", "div", -1);

    let mainCalendarDivToken = state.push("div_calendar", "div", 1);
    mainCalendarDivToken.attrs = [
      ["class", "calendar"],
      ["data-calendar-type", info.attrs.type || "dynamic"],
      ["data-calendar-default-timezone", info.attrs.defaultTimezone],
    ];

    if (info.attrs.defaultView) {
      mainCalendarDivToken.attrs.push([
        "data-calendar-default-view",
        info.attrs.defaultView,
      ]);
    }

    if (info.attrs.weekends) {
      mainCalendarDivToken.attrs.push(["data-weekends", info.attrs.weekends]);
    }

    if (info.attrs.showAddToCalendar) {
      mainCalendarDivToken.attrs.push([
        "data-calendar-show-add-to-calendar",
        info.attrs.showAddToCalendar === "true",
      ]);
    }

    if (info.attrs.fullDay) {
      mainCalendarDivToken.attrs.push([
        "data-calendar-full-day",
        info.attrs.fullDay === "true",
      ]);
    }

    if (info.attrs.hiddenDays) {
      mainCalendarDivToken.attrs.push([
        "data-hidden-days",
        info.attrs.hiddenDays,
      ]);
    }
  },

  after: function (state) {
    state.push("div_calendar", "div", -1);
    state.push("div_calendar_wrap", "div", -1);
  },
};

const groupTimezoneRule = {
  tag: "timezones",

  before: function (state, info) {
    const wrapperDivToken = state.push("div_group_timezones", "div", 1);
    wrapperDivToken.attrs = [
      ["class", "group-timezones"],
      ["data-group", info.attrs.group],
      ["data-size", info.attrs.size || "medium"],
    ];
  },

  after: function (state) {
    state.push("div_group_timezones", "div", -1);
  },
};

function _renderTimezonePicker(state) {
  const timezoneSelectToken = state.push("select_open", "select", 1);
  timezoneSelectToken.attrs = [["class", "discourse-calendar-timezone-picker"]];

  state.push("select_close", "select", -1);
}

export function setup(helper) {
  helper.allowList([
    "div.calendar",
    "div.discourse-calendar-header",
    "div.discourse-calendar-wrap",
    "select.discourse-calendar-timezone-picker",
    "span.discourse-calendar-timezone-wrap",
    "h2.discourse-calendar-title",
    "div[data-calendar-type]",
    "div[data-calendar-default-view]",
    "div[data-calendar-default-timezone]",
    "div[data-weekends]",
    "div[data-hidden-days]",
    "div.group-timezones",
    "div[data-group]",
    "div[data-size]",
  ]);

  helper.registerOptions((opts, siteSettings) => {
    opts.features["discourse-calendar-enabled"] =
      !!siteSettings.calendar_enabled;
  });

  helper.registerPlugin((md) => {
    const features = md.options.discourse.features;
    if (features["discourse-calendar-enabled"]) {
      md.block.bbcode.ruler.push("discourse-calendar", calendarRule);
      md.block.bbcode.ruler.push(
        "discourse-group-timezones",
        groupTimezoneRule
      );
    }
  });
}
