/**
 * Builds a float-kit trigger anchored at the pointer position of an event,
 * so imperative menus open where the user clicked instead of at the edge of
 * the element that received the event.
 *
 * @param {MouseEvent} event
 * @returns {import("@floating-ui/dom").VirtualElement}
 */
export default function virtualElementFromEvent(event) {
  const { clientX, clientY, target } = event;

  return {
    getBoundingClientRect() {
      return {
        x: clientX,
        y: clientY,
        top: clientY,
        bottom: clientY,
        left: clientX,
        right: clientX,
        width: 0,
        height: 0,
      };
    },
    contextElement: target instanceof HTMLElement ? target : undefined,
  };
}
