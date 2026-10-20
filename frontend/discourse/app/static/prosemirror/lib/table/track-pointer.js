export default function trackPointer(startEvent, move, finish) {
  const events = ["pointermove", "pointerup", "pointercancel"];
  const handle = (event) => {
    if (event.pointerId === startEvent.pointerId) {
      (event.type === "pointermove" ? move : finish)(event);
    }
  };
  events.forEach((type) => document.addEventListener(type, handle));
  return () =>
    events.forEach((type) => document.removeEventListener(type, handle));
}
