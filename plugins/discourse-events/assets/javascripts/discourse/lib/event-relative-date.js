import { i18n } from "discourse-i18n";
import guessDateFormat from "./guess-best-date-format";

function _computeCurrentEvent(container, endsAt) {
  const indicator = document.createElement("div");
  indicator.classList.add("indicator");
  container.appendChild(indicator);

  const text = document.createElement("span");
  text.classList.add("text");
  text.innerText = i18n("discourse_post_event.topic_title.ends_in_duration", {
    duration: endsAt.from(moment()),
  });
  container.appendChild(text);
}

function _computePastEvent(container, endsAt) {
  container.innerText = endsAt.from(moment());
}

function _computeFutureEvent(container, startsAt) {
  container.innerText = startsAt.from(moment());
}

export default function eventRelativeDate(container) {
  container.classList.remove("past", "current", "future");
  container.innerHTML = "";

  const startsAt = moment
    .utc(container.dataset.starts_at)
    .tz(moment.tz.guess());
  const endsAt = moment.utc(container.dataset.ends_at).tz(moment.tz.guess());

  const format = guessDateFormat(startsAt);
  let title = startsAt.format(format);
  if (endsAt) {
    title += ` → ${endsAt.format(format)}`;
  }
  container.setAttribute("title", title);

  if (startsAt.isAfter(moment()) && endsAt.isAfter(moment())) {
    container.classList.add("future");
    _computeFutureEvent(container, startsAt);
    return;
  }

  if (startsAt.isBefore(moment()) && endsAt.isAfter(moment())) {
    container.classList.add("current");
    _computeCurrentEvent(container, endsAt);
    return;
  }

  if (startsAt.isBefore(moment()) && endsAt.isBefore(moment())) {
    container.classList.add("past");
    _computePastEvent(container, endsAt);
    return;
  }
}
