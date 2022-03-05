const TIMEFRAME_BASE = {
  enabled: () => true,
  when: () => null,
  icon: "briefcase",
  displayWhen: true,
};

function buildTimeframe(opts) {
  return Object.assign({}, TIMEFRAME_BASE, opts);
}

const TIMEFRAMES = [
  buildTimeframe({
    id: "now",
    format: "h:mm a",
    enabled: (opts) => opts.canScheduleNow,
    when: (time) => time.add(1, "minute"),
    icon: "magic",
  }),
  buildTimeframe({
    id: "later_today",
    format: "h a",
    enabled: (opts) => opts.canScheduleToday,
    when: (time) => time.hour(18).minute(0),
    icon: "far-moon",
  }),
  buildTimeframe({
    id: "tomorrow",
    format: "ddd, h a",
    when: (time, timeOfDay) => time.add(1, "day").hour(timeOfDay).minute(0),
    icon: "far-sun",
  }),
  buildTimeframe({
    id: "later_this_week",
    format: "ddd, h a",
    enabled: (opts) => !opts.canScheduleToday && opts.day > 0 && opts.day < 4,
    when: (time, timeOfDay) => time.add(2, "day").hour(timeOfDay).minute(0),
  }),
  buildTimeframe({
    id: "this_weekend",
    format: "ddd, h a",
    enabled: (opts) => opts.day > 0 && opts.day < 5 && opts.includeWeekend,
    when: (time, timeOfDay) => time.day(6).hour(timeOfDay).minute(0),
    icon: "bed",
  }),
  buildTimeframe({
    id: "next_week",
    format: "ddd, h a",
    enabled: (opts) => opts.day !== 0,
    when: (time, timeOfDay) =>
      time.add(1, "week").day(1).hour(timeOfDay).minute(0),
    icon: "briefcase",
  }),
  buildTimeframe({
    id: "two_weeks",
    format: "MMM D",
    when: (time, timeOfDay) => time.add(2, "week").hour(timeOfDay).minute(0),
    icon: "briefcase",
  }),
  buildTimeframe({
    id: "next_month",
    format: "MMM D",
    enabled: (opts) => opts.now.date() !== moment().endOf("month").date(),
    when: (time, timeOfDay) =>
      time.add(1, "month").startOf("month").hour(timeOfDay).minute(0),
    icon: "briefcase",
  }),
  buildTimeframe({
    id: "two_months",
    format: "MMM D",
    enabled: () => true,
    when: (time, timeOfDay) =>
      time.add(2, "month").startOf("month").hour(timeOfDay).minute(0),
    icon: "briefcase",
  }),
  buildTimeframe({
    id: "three_months",
    format: "MMM D",
    enabled: () => true,
    when: (time, timeOfDay) =>
      time.add(3, "month").startOf("month").hour(timeOfDay).minute(0),
    icon: "briefcase",
  }),
  buildTimeframe({
    id: "four_months",
    format: "MMM D",
    enabled: () => true,
    when: (time, timeOfDay) =>
      time.add(4, "month").startOf("month").hour(timeOfDay).minute(0),
    icon: "briefcase",
  }),
  buildTimeframe({
    id: "six_months",
    format: "MMM D",
    enabled: () => true,
    when: (time, timeOfDay) =>
      time.add(6, "month").startOf("month").hour(timeOfDay).minute(0),
    icon: "briefcase",
  }),
  buildTimeframe({
    id: "one_year",
    format: "MMM D",
    enabled: (opts) => opts.includeFarFuture,
    when: (time, timeOfDay) =>
      time.add(1, "year").startOf("day").hour(timeOfDay).minute(0),
    icon: "briefcase",
  }),
  buildTimeframe({
    id: "forever",
    enabled: (opts) => opts.includeFarFuture,
    when: (time, timeOfDay) => time.add(1000, "year").hour(timeOfDay).minute(0),
    icon: "gavel",
    displayWhen: false,
  }),
  buildTimeframe({
    id: "pick_date_and_time",
    enabled: (opts) => opts.includeDateTime,
    icon: "far-calendar-plus",
  }),
];

let _timeframeById = null;
export function timeframeDetails(id) {
  if (!_timeframeById) {
    _timeframeById = {};
    TIMEFRAMES.forEach((t) => (_timeframeById[t.id] = t));
  }
  return _timeframeById[id];
}

export default function buildTimeframes(options = {}) {
  return TIMEFRAMES.filter((tf) => tf.enabled(options));
}
