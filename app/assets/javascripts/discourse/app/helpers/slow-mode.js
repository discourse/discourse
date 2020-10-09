import I18n from "I18n";

export function fromSeconds(seconds) {
  let initialSeconds = seconds;

  let hours = initialSeconds / 3600;
  if (hours >= 1) {
    initialSeconds = initialSeconds - 3600 * hours;
  } else {
    hours = 0;
  }

  let minutes = initialSeconds / 60;
  if (minutes >= 1) {
    initialSeconds = initialSeconds - 60 * minutes;
  } else {
    minutes = 0;
  }

  return {
    hours: hours,
    minutes: minutes,
    seconds: initialSeconds,
  };
}

export function toSeconds(hours, minutes, seconds) {
  const hoursAsSeconds = parseInt(hours, 10) * 60 * 60;
  const minutesAsSeconds = parseInt(minutes, 10) * 60;

  return parseInt(seconds, 10) + hoursAsSeconds + minutesAsSeconds;
}

export function intervalTextFromSeconds(seconds) {
  const { hours, minutes, secs } = fromSeconds(seconds);
  let hasHours = hours > 0;
  let hasMinutes = minutes > 0;

  if (!hasHours && !hasMinutes) {
    return I18n.t("topic.slow_mode_intervals.seconds", { seconds: secs });
  }

  if (hasHours && hours >= 24) {
    let days = hours / 24;
    return I18n.t("topic.slow_mode_intervals.days", { days: days });
  }

  if (hasHours) {
    if (hasMinutes) {
      return I18n.t("topic.slow_mode_intervals.hours_and_minutes", {
        hours: hours,
        minutes: minutes,
      });
    } else {
      return I18n.t("topic.slow_mode_intervals.hours", { hours: hours });
    }
  } else {
    return I18n.t("topic.slow_mode_intervals.minutes", { minutes: minutes });
  }
}
