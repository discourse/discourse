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

  return { hours, minutes, seconds: initialSeconds };
}

export function toSeconds(hours, minutes, seconds) {
  const hoursAsSeconds = parseInt(hours, 10) * 60 * 60;
  const minutesAsSeconds = parseInt(minutes, 10) * 60;

  return parseInt(seconds, 10) + hoursAsSeconds + minutesAsSeconds;
}

export function durationTextFromSeconds(seconds) {
  return moment.duration(seconds, "seconds").humanize();
}
