export function fromSeconds(seconds) {
  let initialSeconds = seconds;

  let hours = Math.trunc(initialSeconds / 3600);
  if (hours >= 1) {
    initialSeconds = initialSeconds - 3600 * hours;
  } else {
    hours = 0;
  }

  let minutes = Math.trunc(initialSeconds / 60);
  if (minutes >= 1) {
    initialSeconds = initialSeconds - 60 * minutes;
  } else {
    minutes = 0;
  }

  return { hours, minutes, seconds: initialSeconds };
}

export function toSeconds(hours, minutes, seconds) {
  const hoursAsSeconds = hours * 60 * 60;
  const minutesAsSeconds = minutes * 60;

  return seconds + hoursAsSeconds + minutesAsSeconds;
}

export function durationTextFromSeconds(seconds) {
  return moment.duration(seconds, "seconds").humanize();
}

export function cannotPostAgain(user, duration, last_posted_at) {
  let threshold = new Date(last_posted_at);
  threshold = new Date(threshold.getTime() + duration * 1000);

  return !user.staff && new Date() < threshold;
}
