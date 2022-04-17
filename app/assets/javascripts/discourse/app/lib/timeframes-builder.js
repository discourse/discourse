import { TIME_SHORTCUT_TYPES } from "discourse/lib/time-shortcut";
import I18n from "I18n";

export function processDynamicTimeframes(timeframes, timezone) {
  const now = moment.tz(timezone);

  if (now.day() === 0 || now.day() === 5 || now.day() === 6) {
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
}

function hideTimeframe(timeframes, timeframeId) {
  const timeframe = timeframes.findBy("id", timeframeId);
  if (timeframe) {
    timeframe.hidden = true;
  }
}

export function formatTime(timeframes) {
  timeframes.forEach((timeframe) => {
    if (timeframe.time && timeframe.timeFormatKey) {
      timeframe.timeFormatted = timeframe.time.format(
        I18n.t(timeframe.timeFormatKey)
      );
    }
  });
}
