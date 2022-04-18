import I18n from "I18n";

export function formatTime(timeframes) {
  timeframes.forEach((timeframe) => {
    if (timeframe.time && timeframe.timeFormatKey) {
      timeframe.timeFormatted = timeframe.time.format(
        I18n.t(timeframe.timeFormatKey)
      );
    }
  });
}
