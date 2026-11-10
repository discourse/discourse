import { i18n } from "discourse-i18n";

export const MUTE_DURATIONS = [
  { id: "15_minutes", minutes: 15 },
  { id: "1_hour", minutes: 60 },
  { id: "8_hours", minutes: 8 * 60 },
  { id: "24_hours", minutes: 24 * 60 },
];

export function mutedUntilFromNow(minutes) {
  return moment().add(minutes, "minutes").toISOString();
}

// Short time when the mute ends today, otherwise date and time.
export function formatMuteEnd(mutedUntil, currentUser) {
  const timezone = currentUser?.user_option?.timezone || moment.tz.guess();
  const end = moment.tz(mutedUntil, timezone);

  if (end.isSame(moment.tz(timezone), "day")) {
    return end.format("LT");
  }

  return end.format(i18n("dates.long_no_year"));
}
