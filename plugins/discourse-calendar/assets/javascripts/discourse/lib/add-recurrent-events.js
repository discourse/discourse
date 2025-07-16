/* eslint-disable no-console */
import DiscoursePostEventEvent from "../models/discourse-post-event-event";

export default function addRecurrentEvents(events) {
  try {
    return events.flatMap((event) => {
      if (!event.upcomingDates?.length) {
        return [event];
      }

      const upcomingEvents =
        event.upcomingDates?.map((upcomingDate) =>
          DiscoursePostEventEvent.create({
            name: event.name,
            post: event.post,
            category_id: event.categoryId,
            starts_at: upcomingDate.starts_at,
            ends_at: upcomingDate.ends_at,
          })
        ) || [];

      return upcomingEvents;
    });
  } catch (error) {
    console.error("Failed to retrieve events:", error);
    return [];
  }
}
