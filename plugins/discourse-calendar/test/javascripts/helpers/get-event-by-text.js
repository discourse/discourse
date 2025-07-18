export default function getEventByText(text) {
  const events = [...document.querySelectorAll(".fc-day-grid-event")].filter(
    (event) => event.textContent.includes(text)
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
