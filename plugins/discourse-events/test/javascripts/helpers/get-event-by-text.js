export default function getEventByText(text) {
  const events = [
    ...document.querySelectorAll(".fc-daygrid-event-harness"),
  ].filter(
    (event) =>
      event.querySelector(".fc-event-title")?.textContent.trim() === text
  );

  switch (events.length) {
    case 0:
      return;
    case 1:
      return events[0];
    default:
      return events;
  }
}
