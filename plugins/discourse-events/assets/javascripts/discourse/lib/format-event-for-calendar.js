import getURL from "discourse/lib/get-url";
import Category from "discourse/models/category";
import { formatEventName } from "../helpers/format-event-name";
import { isNotFullDayEvent } from "./guess-best-date-format";

function resolveBackgroundColor(event, tagsColorsMap) {
  const { post, categoryId } = event;

  if (post?.topic?.tags) {
    const tagColorEntry = tagsColorsMap.find(
      (entry) =>
        entry.type === "tag" &&
        post.topic.tags.some(
          (t) => (typeof t === "string" ? t : t.name) === entry.slug
        )
    );
    if (tagColorEntry?.color) {
      return tagColorEntry.color;
    }
  }

  const categoryColorEntry = tagsColorsMap.find(
    (entry) => entry.type === "category" && entry.slug === post?.category_slug
  );
  if (categoryColorEntry?.color) {
    return categoryColorEntry.color;
  }

  const categoryColor = Category.findById(categoryId)?.color;
  if (categoryColor) {
    return `#${categoryColor}`;
  }

  return null;
}

export default function formatEventForCalendar(
  event,
  mapEventsToColor,
  timezone
) {
  const tagsColorsMap = JSON.parse(mapEventsToColor);
  const { startsAt, endsAt, post } = event;

  const isAllDay =
    event.allDay || !isNotFullDayEvent(moment(startsAt), moment(endsAt));

  // FullCalendar treats end as exclusive for allDay events,
  // so add one day to make the end date inclusive
  let calendarEnd = endsAt || startsAt;
  if (isAllDay && calendarEnd) {
    calendarEnd = moment(calendarEnd).add(1, "day").format("YYYY-MM-DD");
  }

  return {
    extendedProps: { postEvent: event },
    title: formatEventName(event, timezone),
    start: startsAt,
    end: calendarEnd,
    allDay: isAllDay,
    url: getURL(`/t/-/${post?.topic?.id}/${post?.post_number}`),
    backgroundColor: resolveBackgroundColor(event, tagsColorsMap),
  };
}
