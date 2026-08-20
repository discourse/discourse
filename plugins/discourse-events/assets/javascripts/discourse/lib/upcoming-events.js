import { ajax } from "discourse/lib/ajax";
import { applyValueTransformer } from "discourse/lib/transformer";
import { i18n } from "discourse-i18n";

const DEFAULT_COUNT = 8;
const DEFAULT_UPCOMING_DAYS = 180;

/**
 * Whether an event spans more than a single day.
 *
 * @param {object} event - An event record from the upcoming-events endpoint.
 * @returns {boolean} `true` when the event has an end date on a later day.
 */
export function isMultiDayEvent(event) {
  if (!event.ends_at) {
    return false;
  }
  const startDate = moment(event.starts_at);
  const endDate = moment(event.ends_at);
  return !startDate.isSame(endDate, "day");
}

function addToResult(date, item, result) {
  const day = date.format("DD");
  const monthKey = date.format("YYYY-MM");

  result[monthKey] = result[monthKey] ?? {};
  result[monthKey][day] = result[monthKey][day] ?? [];
  result[monthKey][day].push(item);
}

/**
 * Groups raw events into a `Map` of `month -> Map(day -> events[])`, sorted by
 * month then day, keeping only events whose display date is today or later.
 * Multi-day events that are ongoing surface under today's date.
 *
 * @param {Array<object>} data - The raw events from the endpoint.
 * @returns {Map<string, Map<string, Array<object>>>} The grouped, sorted events.
 */
export function groupUpcomingEventsByMonthAndDay(data) {
  const today = moment();
  const events = data.reduce((result, item) => {
    const startDate = moment(item.starts_at);
    const endDate = item.ends_at ? moment(item.ends_at) : null;

    let displayDate;
    if (!isMultiDayEvent(item)) {
      displayDate = startDate.clone();
    } else if (startDate.isAfter(today, "day")) {
      // Future event — show at its start date.
      displayDate = startDate.clone();
    } else if (today.isSameOrBefore(endDate, "day")) {
      // Ongoing event — show at today's date.
      displayDate = today.clone();
    } else {
      // Past event — skip it.
      return result;
    }

    if (displayDate.isSameOrAfter(today, "day")) {
      addToResult(displayDate, item, result);
    }

    return result;
  }, {});

  const sortedMonths = new Map(
    Object.entries(events).sort(([a], [b]) => a.localeCompare(b))
  );

  const fullySorted = new Map();
  for (const [month, days] of sortedMonths) {
    const sortedDays = new Map(
      Object.entries(days).sort(([a], [b]) => parseInt(a, 10) - parseInt(b, 10))
    );
    fullySorted.set(month, sortedDays);
  }

  return fullySorted;
}

/**
 * Fetches the upcoming events for the given parameters and returns them grouped
 * for rendering, or `null` when there are none (so a data boundary can show its
 * empty state). Shared by the self-fetching `UpcomingEventsList` component and
 * the block's `data.resolve`.
 *
 * `ignoreUnsent: false` so a failed or offline request rejects rather than
 * hanging, letting the caller surface an error.
 *
 * @param {object} [params]
 * @param {number} [params.count] - Maximum number of events to request.
 * @param {number} [params.upcomingDays] - How many days ahead to look.
 * @param {number} [params.categoryId] - Restrict to a category, when set.
 * @param {boolean} [params.includeSubcategories] - Include subcategory events.
 * @returns {Promise<Map<string, Map<string, Array<object>>> | null>} The grouped
 *   events, or `null` when empty.
 */
export async function fetchUpcomingEvents({
  count,
  upcomingDays,
  categoryId,
  includeSubcategories,
} = {}) {
  const data = {
    limit: count ?? DEFAULT_COUNT,
    before: moment()
      .add(upcomingDays ?? DEFAULT_UPCOMING_DAYS, "days")
      .toISOString(),
    after: moment().toISOString(),
    include_ongoing: true,
  };

  if (includeSubcategories) {
    data.include_subcategories = true;
  }

  const showCrossCategory = applyValueTransformer(
    "discourse-calendar-upcoming-events-show-cross-category",
    false
  );
  if (categoryId && !showCrossCategory) {
    data.category_id = categoryId;
  }

  const { events } = await ajax("/discourse-post-event/events", {
    data,
    ignoreUnsent: false,
  });

  const grouped = groupUpcomingEventsByMonthAndDay(events);
  return grouped.size > 0 ? grouped : null;
}

/**
 * The heading shown above an upcoming-events list. Honours the
 * `map_events_title` site setting, which can map a per-category custom title
 * keyed by the current route's category slug; otherwise the localized default.
 *
 * @param {object} params
 * @param {import("discourse/services/router").default} params.router
 * @param {import("discourse/services/site-settings").default} params.siteSettings
 * @returns {string} The title to display.
 */
export function upcomingEventsListTitle({ router, siteSettings }) {
  const defaultTitle = i18n("discourse_post_event.upcoming_events_list.title");
  const titleSetting = siteSettings.map_events_title;

  if (!titleSetting) {
    return defaultTitle;
  }

  const categorySlug = router.currentRoute?.attributes?.category?.slug;
  const titleMap = JSON.parse(titleSetting);
  const customTitle = titleMap.find(
    (entry) => entry.category_slug === categorySlug
  );

  return customTitle?.custom_title ?? defaultTitle;
}
