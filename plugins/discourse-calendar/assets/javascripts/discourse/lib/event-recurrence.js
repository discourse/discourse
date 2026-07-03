import { i18n } from "discourse-i18n";

const ORDINALS = ["first", "second", "third", "fourth"];

export function recurrenceRef(event) {
  if (event.allDay) {
    return moment(event.startsAt, "YYYY-MM-DD");
  }
  return moment(event.startsAt).tz(event.timezone || "UTC");
}

export function recurrenceContext(ref) {
  const weekday = ref.format("dddd");
  const dayOfMonth = ref.date();
  const isLast = dayOfMonth + 7 > ref.daysInMonth();
  const ordinalKey = isLast ? "last" : ORDINALS[Math.ceil(dayOfMonth / 7) - 1];
  const ordinal = i18n(
    `discourse_post_event.builder_modal.recurrence.ordinals.${ordinalKey}`
  );

  return { weekday, ordinal };
}
