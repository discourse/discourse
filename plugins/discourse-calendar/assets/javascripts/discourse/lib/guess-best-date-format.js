export function isNotFullDayEvent(startsAt, endsAt) {
  return (
    startsAt.hours() > 0 ||
    startsAt.minutes() > 0 ||
    (endsAt && (moment(endsAt).hours() > 0 || moment(endsAt).minutes() > 0))
  );
}

export default function guessDateFormat(startsAt, endsAt) {
  let format;
  if (!isNotFullDayEvent(startsAt, endsAt)) {
    format = "LL";
  } else {
    format = "LLL";
  }

  return format;
}
