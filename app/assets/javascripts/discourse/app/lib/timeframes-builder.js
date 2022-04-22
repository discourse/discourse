import {
  TIME_SHORTCUT_TYPES,
  timeShortcuts,
} from "discourse/lib/time-shortcut";
import I18n from "I18n";

export default function buildTimeframes(timezone, options = {}) {
  const timeframes = allTimeframes(timezone);
  formatTime(timeframes);
  processDynamicTimeframes(timeframes, options, timezone);
  return timeframes.filter((t) => !t.hidden);
}

function allTimeframes(timezone) {
  const shortcuts = timeShortcuts(timezone);

  return [
    shortcuts.now(),
    shortcuts.laterToday(),
    shortcuts.tomorrow(),
    shortcuts.laterThisWeek(),
    shortcuts.thisWeekend(),
    shortcuts.monday(),
    shortcuts.twoWeeks(),
    shortcuts.nextMonth(),
    shortcuts.twoMonths(),
    shortcuts.threeMonths(),
    shortcuts.fourMonths(),
    shortcuts.sixMonths(),
    shortcuts.oneYear(),
    shortcuts.forever(),
    shortcuts.custom(),
  ];
}

function processDynamicTimeframes(timeframes, options, timezone) {
  const now = moment.tz(timezone);

  if (
    !options.includeWeekend ||
    now.day() === 0 ||
    now.day() === 5 ||
    now.day() === 6
  ) {
    hideTimeframe(timeframes, TIME_SHORTCUT_TYPES.THIS_WEEKEND);
  }

  if (now.day() === 0) {
    hideTimeframe(timeframes, TIME_SHORTCUT_TYPES.START_OF_NEXT_BUSINESS_WEEK);
  }

  if (now.date() === moment.tz(timezone).endOf("month").date()) {
    hideTimeframe(timeframes, TIME_SHORTCUT_TYPES.NEXT_MONTH);
  }

  if (24 - now.hour() <= 6) {
    hideTimeframe(timeframes, TIME_SHORTCUT_TYPES.LATER_TODAY);
  }

  if (now.day() === 0 || now.day() >= 4) {
    hideTimeframe(timeframes, TIME_SHORTCUT_TYPES.LATER_THIS_WEEK);
  }

  if (!options.includeFarFuture) {
    hideTimeframe(timeframes, TIME_SHORTCUT_TYPES.ONE_YEAR);
    hideTimeframe(timeframes, TIME_SHORTCUT_TYPES.FOREVER);
  }

  if (!options.includeDateTime) {
    hideTimeframe(timeframes, TIME_SHORTCUT_TYPES.CUSTOM);
  }

  if (!options.canScheduleNow) {
    hideTimeframe(timeframes, TIME_SHORTCUT_TYPES.NOW);
  }
}

function hideTimeframe(timeframes, timeframeId) {
  const timeframe = timeframes.findBy("id", timeframeId);
  timeframe.hidden = true;
}

function formatTime(options) {
  options.forEach((option) => {
    if (option.time && option.timeFormatKey) {
      option.timeFormatted = option.time.format(I18n.t(option.timeFormatKey));
    }
  });
}
