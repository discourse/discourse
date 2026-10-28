import { downloadCalendar } from "discourse/lib/download-calendar";
import eventCalendarDetails from "./event-calendar-details.js";

export default function addEventToCalendar(event) {
  downloadCalendar(
    event.name || event.post.topic.title,
    [
      {
        startsAt: event.startsAt,
        endsAt: event.endsAt,
        timezone: event.timezone,
        allDay: event.allDay,
      },
    ],
    {
      rrule:
        event.watchingInvitee?.status === "going" &&
        !event.watchingInvitee.recurring
          ? null
          : event.rrule,
      location: event.location,
      details: eventCalendarDetails(event),
    }
  );
}
