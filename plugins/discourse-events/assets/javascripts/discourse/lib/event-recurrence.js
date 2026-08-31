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
  const nth = Math.ceil(ref.date() / 7);
  // Mirrors RRuleConfigurator: a fifth occurrence is expressed as "last",
  // since not every month has one.
  const ordinalKey = nth === 5 ? "last" : ORDINALS[nth - 1];
  const ordinal = i18n(
    `discourse_post_event.builder_modal.recurrence.ordinals.${ordinalKey}`
  );

  return { weekday, ordinal };
}
