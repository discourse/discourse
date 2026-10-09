import { isTesting } from "discourse/lib/environment";
import I18n, { i18n } from "discourse-i18n";
import guessDateFormat from "./guess-best-date-format";

export function buildEventPreview(eventContainer) {
  eventContainer.innerHTML = "";
  eventContainer.classList.add("discourse-post-event-preview");

  const statusLocaleKey = `discourse_post_event.models.event.status.${
    eventContainer.dataset.status || "public"
  }.title`;
  if (I18n.lookup(statusLocaleKey, { locale: "en" })) {
    const statusContainer = document.createElement("div");
    statusContainer.classList.add("event-preview-status");
    statusContainer.innerText = i18n(statusLocaleKey);
    eventContainer.appendChild(statusContainer);
  }

  const datesContainer = document.createElement("div");
  datesContainer.classList.add("event-preview-dates");

  const startsAt = moment.tz(
    eventContainer.dataset.start,
    eventContainer.dataset.timezone || "UTC"
  );

  const endsAt =
    eventContainer.dataset.end &&
    moment.tz(
      eventContainer.dataset.end,
      eventContainer.dataset.timezone || "UTC"
    );

  const format = guessDateFormat(startsAt, endsAt);
  const guessedTz = isTesting() ? "UTC" : moment.tz.guess();

  let datesString = `<span class='start'>${startsAt
    .tz(guessedTz)
    .format(format)}</span>`;
  if (endsAt) {
    datesString += ` → <span class='end'>${endsAt
      .tz(guessedTz)
      .format(format)}</span>`;
  }
  datesContainer.innerHTML = datesString;

  eventContainer.appendChild(datesContainer);
}
